       IDENTIFICATION DIVISION.
       PROGRAM-ID. VATINV.
       AUTHOR. AR-LEDGER.
       DATE-WRITTEN. 2021-01-11.
      *----------------------------------------------------------------
      * Sales invoice totals.
      * Trade discount, then delivery, then VAT on the taxable amount.
      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01  WS-NET-AMOUNT      PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-DISCOUNT-PCT    PIC 9(2)V99     COMP-3 VALUE ZEROS.
       01  WS-DELIVERY-CHG    PIC 9(5)V99     COMP-3 VALUE ZEROS.
       01  WS-VAT-RATE        PIC 9(2)V99     COMP-3 VALUE ZEROS.
       01  WS-DISC-AMOUNT     PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-TAXABLE-AMT     PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-VAT-AMOUNT      PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-INVOICE-TOTAL   PIC 9(7)V99     COMP-3 VALUE ZEROS.

       PROCEDURE DIVISION.
      *----------------------------------------------------------------
       MAIN-LOGIC.
           MOVE 1840      TO WS-NET-AMOUNT
           MOVE 7.5       TO WS-DISCOUNT-PCT
           MOVE 35        TO WS-DELIVERY-CHG
           MOVE 20        TO WS-VAT-RATE
           PERFORM CALC-DISCOUNT
           PERFORM CALC-VAT
           DISPLAY 'INVOICE TOTAL: ' WS-INVOICE-TOTAL
           STOP RUN.

      *----------------------------------------------------------------
       CALC-DISCOUNT.
           COMPUTE WS-DISC-AMOUNT =
               WS-NET-AMOUNT * WS-DISCOUNT-PCT / 100.
           COMPUTE WS-TAXABLE-AMT =
               WS-NET-AMOUNT + WS-DELIVERY-CHG - WS-DISC-AMOUNT.

      *----------------------------------------------------------------
       CALC-VAT.
           COMPUTE WS-VAT-AMOUNT =
               WS-TAXABLE-AMT * WS-VAT-RATE / 100.
           COMPUTE WS-INVOICE-TOTAL =
               WS-TAXABLE-AMT + WS-VAT-AMOUNT.

       END PROGRAM VATINV.
