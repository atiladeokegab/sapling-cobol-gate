Rule 1: The description of an AI-assisted change must match what the change actually does to computed results, as shown by the modified lines and formal verification.
Rule 2: A change to a computed result is allowed when its description states that change and cites an approved change ticket.
Rule 3: A description that says no computed result changes (a refactor, cleanup or readability change) is false if formal verification shows a computed result changed.
Rule 4: A description that says a computed result changes is false if formal verification proves no computed result changed, or if the result changed in a different field, direction or amount from the one described.
Rule 5: A change whose description is accurate under these rules complies with this policy and is approved for human sign-off.
