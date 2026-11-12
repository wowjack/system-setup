# Software Development Code of Conduct
1. Always follow the principle of least privilege when designing and implementing systems. Components, processes, and users should only have the permissions and access necessary to perform their intended functions.
2. Treat all external input as untrusted.
3. A system should do one thing and do it well. Avoid interspersing unrelated logic and responsibilities.
4. Monolithic systems are acceptable as long as unrelated component logic remains separate, modular, and well organized, and its combination enables a useful abstraction.
5. Read the software architecture description in ARCHITECTURE.md before implementing, or create one if it doesn't exist. In it, describe the component parts of the system , how they work together, and how to test them. If a component is complex enough, it should be considered its own system, and therefore should have its own software architecture description.
6. Software is preferred to be written in Rust or Python, and web projects in vanilla HTML, CSS, and JS (jquery and UI libraries are okay to use). If a different language fits the use case far better, you should use the other language. **NEVER** use unsafe languages that fit the same use case as Rust, like C and C++. All Rust code should pass clippy linting.
7. If there are security relevant parts of the system, create a SECURITY.md file describing the security relevant areas and their risks.
8. Ensure development environments are isolated and reproducible, with dependencies explicitly declared and managed at the project level.
9. Clearly document how to run tests, create new ones, and start development environments in a TESTING.md file.
10. Software should be fully tested wherever possible to ensure correctness.
11. After making changes, run relevant tests, linters, and static analysis tools. Do not claim that functionality works or that tests pass without verifying it. If verification cannot be performed, explicitly document why.
12. Systems should have a simple, clearly documented interface describing how to interact with it in README.md. Performing common actions like starting/stopping a dev server, running tests, linting, cleaning the directory, etc. should be achievable with a simple command or action.
13. Project directory structure should be fully organized. Avoid interspersing unrelated files.
14. Do not make assumptions about ambiguous requirements.
15. Before making changes, understand the relevant existing context. Prefer extending existing abstractions over introducing new ones. Avoid duplicating functionality that already exists.
16. Minimize external dependencies. Prefer standard libraries and existing project dependencies when they adequately satisfy requirements. New dependencies should provide meaningful value that justifies their many costs.
17. Handle errors explicitly and appropriately. Prefer immediate panics over silent errors.
18. Prefer the simplest implementation that adequately and safely satisfies the requirements. Avoid premature optimization, unnecessary abstractions, and solving prospective problems.
19. Keep changes narrowly scoped to the requested functionality.
20. Never conceal incomplete work, failed tests, known limitations, or unresolved issues.
