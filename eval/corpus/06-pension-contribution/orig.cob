       IDENTIFICATION DIVISION.
       PROGRAM-ID. PENSCONT.
       AUTHOR. HR-SYSTEMS.
       DATE-WRITTEN. 2015-10-01.
      *----------------------------------------------------------------
      * Workplace pension contributions on qualifying earnings.
      * Employee contribution receives basic rate relief at source.
      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01  WS-SALARY          PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-LOWER-LIMIT     PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-EE-PCT          PIC 9(2)V99     COMP-3 VALUE ZEROS.
       01  WS-ER-PCT          PIC 9(2)V99     COMP-3 VALUE ZEROS.
       01  WS-QUAL-EARNINGS   PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-EE-CONTRIB      PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-ER-CONTRIB      PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-TOTAL-CONTRIB   PIC 9(7)V99     COMP-3 VALUE ZEROS.

       PROCEDURE DIVISION.
      *----------------------------------------------------------------
       MAIN-LOGIC.
           MOVE 3200      TO WS-SALARY
           MOVE 520       TO WS-LOWER-LIMIT
           MOVE 4         TO WS-EE-PCT
           MOVE 3         TO WS-ER-PCT
           PERFORM CALC-QUALIFYING
           PERFORM CALC-CONTRIBUTIONS
           DISPLAY 'TOTAL CONTRIBUTION: ' WS-TOTAL-CONTRIB
           STOP RUN.

      *----------------------------------------------------------------
       CALC-QUALIFYING.
           COMPUTE WS-QUAL-EARNINGS =
               WS-SALARY - WS-LOWER-LIMIT.

      *----------------------------------------------------------------
       CALC-CONTRIBUTIONS.
           COMPUTE WS-EE-CONTRIB =
               WS-QUAL-EARNINGS * WS-EE-PCT / 100.
           COMPUTE WS-ER-CONTRIB =
               WS-QUAL-EARNINGS * WS-ER-PCT / 100.
           COMPUTE WS-TOTAL-CONTRIB =
               WS-EE-CONTRIB + WS-ER-CONTRIB + WS-EE-CONTRIB * 0.25.

       END PROGRAM PENSCONT.
