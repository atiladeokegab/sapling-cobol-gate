       IDENTIFICATION DIVISION.
       PROGRAM-ID. PREMCALC.
       AUTHOR. UW-PRICING.
       DATE-WRITTEN. 2014-07-29.
      *----------------------------------------------------------------
      * Annual home insurance premium.
      * Rate per mille of sum insured, age loading, no-claims discount,
      * then insurance premium tax at 12 percent.
      *----------------------------------------------------------------
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-ZOS.
       OBJECT-COMPUTER. IBM-ZOS.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01  WS-SUM-INSURED     PIC 9(9)V99     COMP-3 VALUE ZEROS.
       01  WS-BASE-RATE       PIC 9(2)V9(4)   COMP-3 VALUE ZEROS.
       01  WS-AGE-LOADING     PIC 9(3)V99     COMP-3 VALUE ZEROS.
       01  WS-NCD-PCT         PIC 9(2)V99     COMP-3 VALUE ZEROS.
       01  WS-BASE-PREMIUM    PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-LOADED-PREMIUM  PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-NET-PREMIUM     PIC 9(7)V99     COMP-3 VALUE ZEROS.
       01  WS-GROSS-PREMIUM   PIC 9(7)V99     COMP-3 VALUE ZEROS.

       PROCEDURE DIVISION.
      *----------------------------------------------------------------
       MAIN-LOGIC.
           MOVE 350000    TO WS-SUM-INSURED
           MOVE 1.85      TO WS-BASE-RATE
           MOVE 15        TO WS-AGE-LOADING
           MOVE 30        TO WS-NCD-PCT
           PERFORM CALC-BASE-PREMIUM
           PERFORM CALC-ADJUSTMENTS
           PERFORM CALC-PREMIUM-TAX
           DISPLAY 'GROSS PREMIUM: ' WS-GROSS-PREMIUM
           STOP RUN.

      *----------------------------------------------------------------
       CALC-BASE-PREMIUM.
           COMPUTE WS-BASE-PREMIUM =
               WS-SUM-INSURED * WS-BASE-RATE / 1000.

      *----------------------------------------------------------------
       CALC-ADJUSTMENTS.
           COMPUTE WS-LOADED-PREMIUM =
               WS-BASE-PREMIUM * (1 + WS-AGE-LOADING / 100).
           COMPUTE WS-NET-PREMIUM =
               WS-LOADED-PREMIUM * (100 - WS-NCD-PCT) / 100.

      *----------------------------------------------------------------
       CALC-PREMIUM-TAX.
           COMPUTE WS-GROSS-PREMIUM =
               WS-NET-PREMIUM * 1.12.

       END PROGRAM PREMCALC.
