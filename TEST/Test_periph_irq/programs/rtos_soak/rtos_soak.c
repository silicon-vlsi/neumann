// rtos_soak.c - long FreeRTOS run (a few million clocks) to look for drift, lost wake-ups,
// stack overflow or lock-ups under continuous scheduling. Tick = 10 000 clocks (10 kHz).
//
// Tasks (priority):
//   producer (3)  sends 1..N_ITEMS through a 4-entry queue, vTaskDelay(1) every 50 items
//   consumer (2)  receives them, checks order, sums
//   mutex A/B (2)  each adds 1 to a shared counter N_MUTEX times under a mutex, with taskYIELD
//                    inside the critical section
//   ping / pong (2)  hand a token back and forth N_PING times with task notifications
//   ticker (3)    N_TICKS x vTaskDelay(1)
//   busy (1)      never blocks (time slicing / preemption)
//   checker (1)   waits for all, then checks the tick count against mtime and writes results
// Results (golden/rtos_soak.golden):
//   [0] sum of items 4501500 (N_ITEMS = 3000)  [1] items 3000  [2] order ok 1
//   [3] mutex counter 2000 (2 x 1000)          [4] ping-pong rounds 1000 each side: 1000
//   [5] pong rounds 1000                       [6] ticker loops 200
//   [7] tick count agrees with (mtime - mtime at scheduler start) / 10 000 within 2 ticks: 1
//   [8] busy task ran: 1                        [9] every task kept > 16 free stack words: 1
//   [10] queue empty at the end: 1
#define TEST_NO_C_TRAP
#include "test.h"
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"

#define N_ITEMS 3000
#define N_MUTEX 1000
#define N_PING  1000
#define N_TICKS 200
#define TASK_STACK 112                   /* words; overflow check 2 is on */
#define CLK_PER_TICK (configCPU_CLOCK_HZ / configTICK_RATE_HZ)

static QueueHandle_t q;
static SemaphoreHandle_t mtx;
static TaskHandle_t ping_h, pong_h, h[10];
static volatile uint32_t sum, received, order_ok = 1, shared, mutex_done, ping_n, pong_n;
static volatile uint32_t ticker_loops, busy_count, done_mask, mtime_start;

static void fail(uint32_t code) { taskDISABLE_INTERRUPTS(); SIG_STATUS = code; for (;;) ; }
void vAssertCalled(void) { fail(0xBAD0A000u); }
void vApplicationStackOverflowHook(TaskHandle_t t, char *name) { (void)t; (void)name; fail(0xBAD0B000u); }
void vApplicationMallocFailedHook(void) { fail(0xBAD0C000u); }
void freertos_risc_v_application_exception_handler(void)
{
  uint32_t c; __asm volatile("csrr %0, mcause" : "=r"(c));
  fail(0xBAD0F000u | (c & 0xFFFu));
}
void freertos_risc_v_application_interrupt_handler(void)
{
  uint32_t c; __asm volatile("csrr %0, mcause" : "=r"(c));
  fail(0xBAD0E000u | (c & 0xFFFu));
}

static void mark(uint32_t bit) { taskENTER_CRITICAL(); done_mask |= bit; taskEXIT_CRITICAL(); }

static void producer(void *p)
{
  (void)p;
  for (uint32_t i = 1; i <= N_ITEMS; i++) {
    xQueueSend(q, (const void *)&i, portMAX_DELAY);
    if (i % 50 == 0) vTaskDelay(1);
  }
  mark(1);
  vTaskSuspend(NULL);
}

static void consumer(void *p)
{
  (void)p;
  for (uint32_t i = 1; i <= N_ITEMS; i++) {
    uint32_t v;
    if (xQueueReceive(q, &v, portMAX_DELAY) != pdPASS || v != i) order_ok = 0;
    sum += v;
    received++;
  }
  mark(2);
  vTaskSuspend(NULL);
}

static void mutex_task(void *p)
{
  (void)p;
  for (int i = 0; i < N_MUTEX; i++) {
    xSemaphoreTake(mtx, portMAX_DELAY);
    uint32_t v = shared;
    taskYIELD();
    shared = v + 1;
    xSemaphoreGive(mtx);
  }
  taskENTER_CRITICAL(); mutex_done++; taskEXIT_CRITICAL();
  vTaskSuspend(NULL);
}

static void ping(void *p)
{
  (void)p;
  for (int i = 0; i < N_PING; i++) {
    xTaskNotifyGive(pong_h);
    ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
    ping_n++;
  }
  mark(4);
  vTaskSuspend(NULL);
}

static void pong(void *p)
{
  (void)p;
  for (int i = 0; i < N_PING; i++) {
    ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
    pong_n++;
    xTaskNotifyGive(ping_h);
  }
  mark(8);
  vTaskSuspend(NULL);
}

static void ticker(void *p)
{
  (void)p;
  for (int i = 0; i < N_TICKS; i++) { vTaskDelay(1); ticker_loops++; }
  mark(16);
  vTaskSuspend(NULL);
}

static void busy(void *p)
{
  (void)p;
  for (;;) busy_count++;
}

static void checker(void *p)
{
  (void)p;
  while (!((done_mask & 31) == 31 && mutex_done == 2)) vTaskDelay(1);
  vTaskDelay(3);                                   // busy runs; back only through preemption
  taskENTER_CRITICAL();
  uint32_t ticks = xTaskGetTickCount();
  uint32_t mt = CLINT_MTIME;
  taskEXIT_CRITICAL();
  int32_t diff = (int32_t)ticks - (int32_t)((mt - mtime_start) / CLK_PER_TICK);   // no drift
  uint32_t stacks_ok = 1;
  for (int i = 0; i < 10; i++)
    if (h[i] && uxTaskGetStackHighWaterMark(h[i]) <= 16) stacks_ok = 0;
  uint32_t n = 0;
  RESULT[n++] = sum;
  RESULT[n++] = received;
  RESULT[n++] = order_ok;
  RESULT[n++] = shared;
  RESULT[n++] = ping_n;
  RESULT[n++] = pong_n;
  RESULT[n++] = ticker_loops;
  RESULT[n++] = (diff >= -2 && diff <= 2);
  RESULT[n++] = busy_count != 0;
  RESULT[n++] = stacks_ok;
  RESULT[n++] = uxQueueMessagesWaiting(q) == 0;
  RESULT_N = n;
  SIG_STATUS = SIG_PASS;
  for (;;) vTaskDelay(100);
}

uint32_t main(void)
{
  q = xQueueCreate(4, sizeof(uint32_t));
  mtx = xSemaphoreCreateMutex();
  if (!q || !mtx) return 0xBAD0C001u;
  int ok = 1;
  ok &= xTaskCreate(checker,    "chk",  configMINIMAL_STACK_SIZE, NULL, 1, &h[0]) == pdPASS;
  ok &= xTaskCreate(producer,   "prod", TASK_STACK, NULL, 3, &h[1]) == pdPASS;
  ok &= xTaskCreate(consumer,   "cons", TASK_STACK, NULL, 2, &h[2]) == pdPASS;
  ok &= xTaskCreate(mutex_task, "mA",   TASK_STACK, NULL, 2, &h[3]) == pdPASS;
  ok &= xTaskCreate(mutex_task, "mB",   TASK_STACK, NULL, 2, &h[4]) == pdPASS;
  ok &= xTaskCreate(pong,       "pong", TASK_STACK, NULL, 2, &pong_h) == pdPASS;
  ok &= xTaskCreate(ping,       "ping", TASK_STACK, NULL, 2, &ping_h) == pdPASS;
  ok &= xTaskCreate(ticker,     "tick", TASK_STACK, NULL, 3, &h[8]) == pdPASS;
  ok &= xTaskCreate(busy,       "busy", TASK_STACK, NULL, 1, &h[9]) == pdPASS;
  if (!ok) return 0xBAD0C002u;
  h[6] = pong_h; h[7] = ping_h;   /* h[5] unused */
  mtime_start = CLINT_MTIME;       // the port arms the first tick from here
  vTaskStartScheduler();
  return 0xBAD0D000u;
}
