## Process this file with automake to produce Makefile.in

exampledir=${datadir}/@PACKAGE@/Examples/Console

if ENABLE_EXAMPLES
if ENABLE_CONSOLE

example_PROGRAMS = ConsoleTest

ConsoleTest_SOURCES = ConsoleTest.c
ConsoleTest_LDADD = -lbcunit -lbcunitexamples
ConsoleTest_LDFLAGS = -L.. -lm
INCLUDES = -I..

if ENABLE_CURSES
ConsoleTest_LDADD += -l$(CURSES_LIB)
endif

example_DATA = README

endif
endif
