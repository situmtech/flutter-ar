## Changed:

- Added new algorithm to set coordinates to which the arrow is pointing during guidance and force this coordinates to be updated always.
- Increased default distance to point to coordinates to 25 m.
- Changed starting AR message from "AR Loading" to "Optimizing AR"
- Faster decrement of the quality metric threhsold to enforce a world reset. This reduces the time before a reset occurs which improves cases where the AR guidance is in an incorrect state.
- Updated flutter plugin version to 3.18.1
