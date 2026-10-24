       IDENTIFICATION DIVISION.
       PROGRAM-ID. ODFEE.
       AUTHOR. D-PRZYBYLSKI.
       DATE-WRITTEN. 2016-04-18.
      *----------------------------------------------------------------
      * Monthly overdraft charges.
      * Interest on the overdrawn balance, a charge per unpaid item and
      * a daily usage fee.
      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01  WS-OD-BALANCE      PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-OD-RATE         PIC 9V9(4)      COMP-3 VALUE ZEROS.
       01  WS-OD-DAYS         PIC 9(3)        COMP-3 VALUE ZEROS.
       01  WS-UNPAID-ITEMS    PIC 9(3)        COMP-3 VALUE ZEROS.
       01  WS-OD-INTEREST     PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-ITEM-CHARGES    PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-OD-FEE-TOTAL    PIC 9(7)V99     COMP-3 VALUE ZEROS.

       PROCEDURE DIVISION.
      *----------------------------------------------------------------
       MAIN-LOGIC.
           MOVE 640       TO WS-OD-BALANCE
           MOVE 0.3990    TO WS-OD-RATE
           MOVE 9         TO WS-OD-DAYS
           MOVE 2         TO WS-UNPAID-ITEMS
           PERFORM CALC-OD-INTEREST
           PERFORM CALC-OD-CHARGES
           DISPLAY 'OVERDRAFT CHARGES: ' WS-OD-FEE-TOTAL
           STOP RUN.

      *----------------------------------------------------------------
       CALC-OD-INTEREST.
           COMPUTE WS-OD-INTEREST =
               WS-OD-BALANCE * WS-OD-RATE / 365 * WS-OD-DAYS.

      *----------------------------------------------------------------
       CALC-OD-CHARGES.
           COMPUTE WS-ITEM-CHARGES =
               WS-UNPAID-ITEMS * 35.
           COMPUTE WS-OD-FEE-TOTAL =
               WS-OD-INTEREST + WS-ITEM-CHARGES + WS-OD-DAYS * 5.

       END PROGRAM ODFEE.
