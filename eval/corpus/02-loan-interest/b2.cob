       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOANINT.
       AUTHOR. M-HALVORSEN.
       DATE-WRITTEN. 2017-09-02.
      *----------------------------------------------------------------
      * Simple daily interest on a personal loan for a billing period.
      * Actual/365 day count; arrangement fee added to the amount due.
      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01  WS-PRINCIPAL       PIC 9(9)V99     COMP-3 VALUE ZEROS.
       01  WS-ANNUAL-RATE     PIC 9V9(4)      COMP-3 VALUE ZEROS.
       01  WS-DAYS            PIC 9(3)        COMP-3 VALUE ZEROS.
       01  WS-ARRANGE-FEE     PIC 9(5)V99     COMP-3 VALUE ZEROS.
       01  WS-DAILY-INT       PIC 9(7)V9(4)   COMP-3 VALUE ZEROS.
       01  WS-PERIOD-INT      PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-TOTAL-DUE       PIC 9(9)V99     COMP-3 VALUE ZEROS.

       PROCEDURE DIVISION.
      *----------------------------------------------------------------
       MAIN-LOGIC.
           MOVE 25000     TO WS-PRINCIPAL
           MOVE 0.0649    TO WS-ANNUAL-RATE
           MOVE 31        TO WS-DAYS
           MOVE 150       TO WS-ARRANGE-FEE
           PERFORM CALC-INTEREST
           PERFORM CALC-TOTAL-DUE
           DISPLAY 'TOTAL DUE: ' WS-TOTAL-DUE
           STOP RUN.

      *----------------------------------------------------------------
       CALC-INTEREST.
           COMPUTE WS-DAILY-INT =
               WS-PRINCIPAL * WS-ANNUAL-RATE / 365.
           COMPUTE WS-PERIOD-INT =
               WS-DAILY-INT * WS-DAYS.

      *----------------------------------------------------------------
       CALC-TOTAL-DUE.
           COMPUTE WS-TOTAL-DUE =
               WS-PRINCIPAL + WS-PERIOD-INT.

       END PROGRAM LOANINT.
