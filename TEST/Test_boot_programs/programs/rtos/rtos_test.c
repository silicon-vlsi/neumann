// rtos_test.c - FreeRTOS on the neumann SoC: scheduler, tick interrupt (CLINT MTI),
// ecall yield, queues, mutex, delays, time slicing, task notifications.
//
// Tasks (priority):
//   producer (3)  sends 1..N_ITEMS to a queue, vTaskDelay(2) after every 5 items
//   consumer (2)  receives N_ITEMS, checks order, sums them
//   ticker   (3)  10 x vTaskDelay(1), records the tick count
//   mutex A/B (2) each adds 1 to a shared counter 20 times under a mutex, with taskYIELD
//   busy     (1)  never blocks: only runs because of preemption / time slicing
//   checker  (1)  same priority as busy; waits for all, then sleeps 3 ticks so that busy
//                 runs; busy never blocks, so the checker only gets the CPU back through the
//                 tick interrupt (preemption + time slicing). Then writes the results and
//                 SIG_STATUS = 0xC0DE0001
// Results (golden/rtos.golden):
//   [0] sum of received items (210)  [1] items received (20)  [2] order ok (1)
//   [3] ticker loops (10)  [4] ticks >= 10 seen by ticker (1)  [5] mutex counter (40)
//   [6] busy task ran (1)  [7] notification value received (0x5A5A)  [8] queue empty at end (1)
// Errors: SIG_STATUS = 0xBAD0A000 assert, 0xBAD0B000 stack overflow, 0xBAD0C000 malloc,
//         0xBAD0F000 | mcause unexpected trap, 0xBAD0E000 | id unexpected interrupt.
#define TEST_NO_C_TRAP
#include "test.h"
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"

#define N_ITEMS 20

static QueueHandle_t q;
static SemaphoreHandle_t mtx;
static TaskHandle_t checker_h;
static volatile uint32_t sum, received, order_ok = 1, ticker_loops, ticker_ok;
static volatile uint32_t shared, mutex_done, busy_count, notify_val;
static volatile uint32_t prod_done, cons_done, tick_done;

static void fail(uint32_t code) { taskDISABLE_INTERRUPTS(); SIG_STATUS = code; for (;;) ; }
void vAssertCalled(void) { fail(0xBAD0A000u); }
void vApplicationStackOverflowHook(TaskHandle_t t, char *name) { (void)t; (void)name; fail(0xBAD0B000u); }
void vApplicationMallocFailedHook(void) { fail(0xBAD0C000u); }
// called by the port for exceptions other than ecall, and for interrupts other than MTI
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

static void producer(void *p)
{
  (void)p;
  uint32_t k = 0;
  for (uint32_t i = 1; i <= N_ITEMS; i++) {
    xQueueSend(q, (const void *)&i, portMAX_DELAY);
    if (++k == 5) { k = 0; vTaskDelay(2); }
  }
  prod_done = 1;
  vTaskSuspend(NULL);
}

static void consumer(void *p)
{
  (void)p;
  for (uint32_t i = 1; i <= N_ITEMS; i++) {
    uint32_t v;
    if (xQueueReceive(q, &v, portMAX_DELAY) != pdPASS) order_ok = 0;
    if (v != i) order_ok = 0;
    sum += v;
    received++;
  }
  cons_done = 1;
  xTaskNotify(checker_h, 0x5A5Au, eSetValueWithOverwrite);
  vTaskSuspend(NULL);
}

static void ticker(void *p)
{
  (void)p;
  TickType_t t0 = xTaskGetTickCount();
  for (int i = 0; i < 10; i++) { vTaskDelay(1); ticker_loops++; }
  ticker_ok = (xTaskGetTickCount() - t0) >= 10;
  tick_done = 1;
  vTaskSuspend(NULL);
}

static void mutex_task(void *p)
{
  (void)p;
  for (int i = 0; i < 20; i++) {
    xSemaphoreTake(mtx, portMAX_DELAY);
    uint32_t v = shared;
    taskYIELD();                       // try to break the critical section (mutex must hold)
    shared = v + 1;
    xSemaphoreGive(mtx);
  }
  taskENTER_CRITICAL(); mutex_done++; taskEXIT_CRITICAL();
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
  uint32_t nv = 0;
  xTaskNotifyWait(0, 0xFFFFFFFFu, &nv, portMAX_DELAY);   // from the consumer
  notify_val = nv;
  while (!(prod_done && cons_done && tick_done && mutex_done == 2)) vTaskDelay(1);
  vTaskDelay(3);                       // busy runs now; we come back only by preemption
  uint32_t n = 0;
  RESULT[n++] = sum;
  RESULT[n++] = received;
  RESULT[n++] = order_ok;
  RESULT[n++] = ticker_loops;
  RESULT[n++] = ticker_ok;
  RESULT[n++] = shared;
  RESULT[n++] = busy_count != 0;
  RESULT[n++] = notify_val;
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
  if (xTaskCreate(checker,  "chk",  configMINIMAL_STACK_SIZE, NULL, 1, &checker_h) != pdPASS ||
      xTaskCreate(producer, "prod", configMINIMAL_STACK_SIZE, NULL, 3, NULL) != pdPASS ||
      xTaskCreate(consumer, "cons", configMINIMAL_STACK_SIZE, NULL, 2, NULL) != pdPASS ||
      xTaskCreate(ticker,   "tick", configMINIMAL_STACK_SIZE, NULL, 3, NULL) != pdPASS ||
      xTaskCreate(mutex_task, "mA", configMINIMAL_STACK_SIZE, NULL, 2, NULL) != pdPASS ||
      xTaskCreate(mutex_task, "mB", configMINIMAL_STACK_SIZE, NULL, 2, NULL) != pdPASS ||
      xTaskCreate(busy,     "busy", configMINIMAL_STACK_SIZE, NULL, 1, NULL) != pdPASS)
    return 0xBAD0C002u;
  vTaskStartScheduler();
  return 0xBAD0D000u;                   // scheduler returned: error
}
