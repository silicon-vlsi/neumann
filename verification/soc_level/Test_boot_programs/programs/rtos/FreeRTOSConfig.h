/* FreeRTOSConfig.h - FreeRTOS on the neumann SoC (RV32IC, Wally CLINT). */
#ifndef FREERTOS_CONFIG_H
#define FREERTOS_CONFIG_H

/* Wally CLINT: mtime and mtimecmp (hart 0); mtime counts every clock (100 MHz in the tb) */
#define configMTIME_BASE_ADDRESS        ( 0x0200BFF8UL )
#define configMTIMECMP_BASE_ADDRESS     ( 0x02004000UL )
#define configCPU_CLOCK_HZ              ( 100000000UL )
#define configTICK_RATE_HZ              ( ( TickType_t ) 10000 )   /* 10 k clocks per tick: short sim */

#define configUSE_PREEMPTION            1
#define configUSE_TIME_SLICING          1
#define configUSE_PORT_OPTIMISED_TASK_SELECTION 0
#define configMAX_PRIORITIES            5
#define configMINIMAL_STACK_SIZE        ( ( unsigned short ) 128 )   /* words */
#define configISR_STACK_SIZE_WORDS      128
#define configTOTAL_HEAP_SIZE           ( ( size_t ) 5400 )
#define configMAX_TASK_NAME_LEN         8
#define configTICK_TYPE_WIDTH_IN_BITS   TICK_TYPE_WIDTH_32_BITS
#define configIDLE_SHOULD_YIELD         1
#define configUSE_IDLE_HOOK             0
#define configUSE_TICK_HOOK             0
#define configUSE_MUTEXES               1
#define configUSE_COUNTING_SEMAPHORES   0
#define configUSE_RECURSIVE_MUTEXES     0
#define configQUEUE_REGISTRY_SIZE       0
#define configUSE_TIMERS                0
#define configUSE_CO_ROUTINES           0
#define configUSE_TRACE_FACILITY        0
#define configGENERATE_RUN_TIME_STATS   0
#define configUSE_STATS_FORMATTING_FUNCTIONS 0
#define configSUPPORT_DYNAMIC_ALLOCATION 1
#define configSUPPORT_STATIC_ALLOCATION 0
#define configCHECK_FOR_STACK_OVERFLOW  2
#define configUSE_MALLOC_FAILED_HOOK    1
#define configUSE_TASK_NOTIFICATIONS    1

#define INCLUDE_vTaskSuspend            1
#define INCLUDE_vTaskDelay              1
#define INCLUDE_vTaskDelete             0
#define INCLUDE_xTaskGetSchedulerState  0
#define INCLUDE_uxTaskPriorityGet       0
#define INCLUDE_vTaskPrioritySet        0

#ifndef __ASSEMBLER__
void vAssertCalled( void );
#define configASSERT( x )    if( ( x ) == 0 ) vAssertCalled()
#endif

#endif /* FREERTOS_CONFIG_H */
