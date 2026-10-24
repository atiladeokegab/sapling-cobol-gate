       IDENTIFICATION DIVISION.
       PROGRAM-ID. MTGLTV.
       AUTHOR. MORTGAGE-OPS.
       DATE-WRITTEN. 2013-05-16.
      *----------------------------------------------------------------
      * Mortgage completion fees.
      * Higher lending charge on the loan above 75 percent of valuation,
      * product fee and fixed valuation fee added to the advance.
      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01  WS-LOAN-AMT        PIC 9(9)V99     COMP-3 VALUE ZEROS.
       01  WS-PROPERTY-VAL    PIC 9(9)V99     COMP-3 VALUE ZEROS.
       01  WS-HLC-RATE        PIC 9(2)V99     COMP-3 VALUE ZEROS.
       01  WS-PRODUCT-FEE     PIC 9(5)V99     COMP-3 VALUE ZEROS.
       01  WS-EXCESS-LEND     PIC S9(9)V99    COMP-3 VALUE ZEROS.
       01  WS-HLC-FEE         PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-TOTAL-FEES      PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-ADVANCE         PIC 9(9)V99     COMP-3 VALUE ZEROS.

       PROCEDURE DIVISION.
      *----------------------------------------------------------------
       MAIN-LOGIC.
           MOVE 270000    TO WS-LOAN-AMT
           MOVE 320000    TO WS-PROPERTY-VAL
           MOVE 2.5       TO WS-HLC-RATE
           MOVE 999       TO WS-PRODUCT-FEE
           PERFORM CALC-EXCESS-LENDING
           PERFORM CALC-FEES
           DISPLAY 'TOTAL ADVANCE: ' WS-ADVANCE
           STOP RUN.

      *----------------------------------------------------------------
       CALC-EXCESS-LENDING.
           COMPUTE WS-EXCESS-LEND =
               WS-LOAN-AMT - WS-PROPERTY-VAL * 0.75.

      *----------------------------------------------------------------
       CALC-FEES.
           COMPUTE WS-HLC-FEE =
               WS-LOAN-AMT * WS-HLC-RATE / 100.
           COMPUTE WS-TOTAL-FEES =
               WS-PRODUCT-FEE + WS-HLC-FEE + 199.
           COMPUTE WS-ADVANCE =
               WS-LOAN-AMT + WS-TOTAL-FEES.

       END PROGRAM MTGLTV.
