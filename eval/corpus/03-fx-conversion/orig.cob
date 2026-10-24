       IDENTIFICATION DIVISION.
       PROGRAM-ID. FXCONV.
       AUTHOR. TREASURY-OPS.
       DATE-WRITTEN. 2020-06-22.
      *----------------------------------------------------------------
      * Retail foreign exchange conversion.
      * Customer rate is the mid rate less spread; commission is a
      * percentage of the converted amount plus a fixed charge.
      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01  WS-SOURCE-AMT      PIC 9(9)V99     COMP-3 VALUE ZEROS.
       01  WS-MID-RATE        PIC 9(3)V9(6)   COMP-3 VALUE ZEROS.
       01  WS-SPREAD-PCT      PIC 9V9(4)      COMP-3 VALUE ZEROS.
       01  WS-CUST-RATE       PIC 9(3)V9(6)   COMP-3 VALUE ZEROS.
       01  WS-TARGET-AMT      PIC 9(9)V99     COMP-3 VALUE ZEROS.
       01  WS-COMMISSION      PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-NET-TARGET      PIC 9(9)V99     COMP-3 VALUE ZEROS.

       PROCEDURE DIVISION.
      *----------------------------------------------------------------
       MAIN-LOGIC.
           MOVE 1000      TO WS-SOURCE-AMT
           MOVE 1.172450  TO WS-MID-RATE
           MOVE 0.0150    TO WS-SPREAD-PCT
           PERFORM CALC-CUSTOMER-RATE
           PERFORM CALC-CONVERSION
           DISPLAY 'AMOUNT PAID OUT: ' WS-NET-TARGET
           STOP RUN.

      *----------------------------------------------------------------
       CALC-CUSTOMER-RATE.
           COMPUTE WS-CUST-RATE =
               WS-MID-RATE * (1 - WS-SPREAD-PCT).

      *----------------------------------------------------------------
       CALC-CONVERSION.
           COMPUTE WS-TARGET-AMT =
               WS-SOURCE-AMT * WS-CUST-RATE.
           COMPUTE WS-COMMISSION =
               WS-TARGET-AMT * 0.0025 + 1.50.
           COMPUTE WS-NET-TARGET =
               WS-TARGET-AMT - WS-COMMISSION.

       END PROGRAM FXCONV.
