## DDR-rrh9hx — Add dedicated delete_with_retry function
Date: 2026-09-04  Developer: andrewjmorrell  Trace: T-srcdemo
Options considered: omit a delete helper entirely; combine get/put/post/delete into a single generic method-parameterized function; add a dedicated delete_with_retry function
Chosen: dedicated delete_with_retry function
Rationale: Authored delete_with_retry to complete the set of calls. Considered not putting it in but felt it was better to have a new method for this. Also considered combining all methods into a single method but decided against it because it makes the code easier to understand.
Conceived-by: human
