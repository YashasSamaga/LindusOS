/************************************************************************************************/
//	Hardware Abstraction Layer x86
//	Processor Interface
//
//	cpu.c
//	Provides an interface to work with the processor.
//
//	Date: January 6th 2017
//
/************************************************************************************************/
#include <hal.h>
#include <cpu/cpu.h>
#include <cpu/gdt.h>
#include <cpu/idt.h>

/*==============================================================================================*/
// Interface Functions
/*==============================================================================================*/
/*************************************************************************************************
	<summary>cpu_initialize</summary>
	<para>initilizes the CPU</para>
*************************************************************************************************/
int cpu_initialize() 
{
	initilize_gdt();
	initilize_idt();	
	return 0;
}

/*************************************************************************************************
	<summary>cpu_shutdown</summary>
	<para>shutdown the CPU</para>
*************************************************************************************************/
void cpu_shutdown() 
{

}
