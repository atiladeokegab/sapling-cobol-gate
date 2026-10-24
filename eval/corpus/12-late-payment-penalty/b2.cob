       IDENTIFICATION DIVISION.
       PROGRAM-ID. LATEPEN.
       AUTHOR. CREDIT-CONTROL.
       DATE-WRITTEN. 2016-12-07.
      *----------------------------------------------------------------
      * Statutory interest and compensation on overdue invoices.
      * Daily interest at base rate plus 8 percent, plus a fixed
      * compensation amount.
      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01  WS-OVERDUE-AMT     PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-BASE-RATE       PIC 9(2)V99     COMP-3 VALUE ZEROS.
       01  WS-DAYS-LATE       PIC 9(3)        COMP-3 VALUE ZEROS.
       01  WS-FIXED-COMP      PIC 9(3)V99     COMP-3 VALUE ZEROS.
       01  WS-DAILY-INT       PIC 9(5)V9(4)   COMP-3 VALUE ZEROS.
       01  WS-PENALTY-INT     PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-TOTAL-CLAIM     PIC 9(7)V99     COMP-3 VALUE ZEROS.

       PROCEDURE DIVISION.
      *----------------------------------------------------------------
       MAIN-LOGIC.
           MOVE 12600     TO WS-OVERDUE-AMT
           MOVE 4.75      TO WS-BASE-RATE
           MOVE 47        TO WS-DAYS-LATE
           MOVE 70        TO WS-FIXED-COMP
           PERFORM CALC-DAILY-INTEREST
           PERFORM CALC-PENALTY
           DISPLAY 'TOTAL CLAIM: ' WS-TOTAL-CLAIM
           STOP RUN.

      *----------------------------------------------------------------
       CALC-DAILY-INTEREST.
           COMPUTE WS-DAILY-INT =
               WS-OVERDUE-AMT * WS-BASE-RATE + 8 / 100 / 365.

      *----------------------------------------------------------------
       CALC-PENALTY.
           COMPUTE WS-PENALTY-INT =
               WS-DAILY-INT * WS-DAYS-LATE.
           COMPUTE WS-TOTAL-CLAIM =
               WS-OVERDUE-AMT + WS-PENALTY-INT + WS-FIXED-COMP.

       END PROGRAM LATEPEN.
