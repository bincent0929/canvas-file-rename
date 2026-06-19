# Bash Project Requirements

## Project Scope

Design and implement a non-trivial Bash utility that performs a system, file, or data analysis task using standard Unix command-line tools.

Your project must demonstrate:

- Structured Bash programming
- Decisions based on command exit status
- Controlled parsing and reporting

## Project Selection

You will design your own project. It is recommended that you discuss your project idea with the instructor before starting.

## Functional Requirements

### Command-Line Interface

Your script must:

- Be invoked from the command line
- Support at least 2 modes or subcommands
- Print a clear usage message when invoked incorrectly

### Functions and Structure

Your script must contain at least 6 functions.

Those functions must include:

- 1 `main` function
- 1 `usage` function
  - This function must be called when script arguments are incorrect

At least 2 functions must:

- Take input through parameters
- Return status only, using `0` for success and non-zero for failure
- Not print output

At least 1 function must:

- Print data to stdout
- Be used through command substitution

Only the `main` and `usage` functions may terminate the script.

### Exit Status Driven Logic

Your script must make at least 5 decisions based on exit status.

These decisions must distinguish between:

- Success
- Failure

### Exit Codes

Your script must use these exit codes:

- `0` - Pass / success
- `1` - Fail
- `2` - Incorrect usage

### Command-Line Tools

Your script must use at least 5 standard command-line tools.

Tools must be invoked directly. Examples include:

- `ls`, `find`, `wc`, `cut`, `sort`, `uniq`, `head`, `tail`
- `grep`, `stat`, `du`, `df`, `ps`, `who`, `last`
- `tar`, `sha256sum`, `diff`, `date`, `file`
- `zip`, `gzip`, `7z`, `cmp`

### Redirection

Your script must use redirection at least 7 times.

### Output Parsing and Manipulation

Your script must compute derived metrics using parsing pipelines.

Examples include:

- Counts
- Top-N lists
- Summaries
- Comparisons

### Testability

Your project must be fully testable on a local machine.

It must not require privileged access or access to a remote user account.

## Required Output

Each script must produce:

- Human-readable output
- Optional report file

## Deliverables

Submit all deliverables as a single zip file.

Your submission must include:

- A single `.sh` Bash script
- `README.md`

The `README.md` must include:

- Project description
- Supported modes and options
- Exit code meanings
- How to test locally

Use Markdown formatting for the README.

## Code Defense

All students must participate in their assigned code defense to receive a grade for the project.

Five students will be chosen at random to publicly defend their code. For each public defense, two other students will be randomly chosen to act as the panel. All other students will complete a one-on-one code defense.

Code defenses will take approximately 20 minutes:

- The defending student will have 10 minutes to explain their project and code
- Panel members will have 10 minutes to ask questions about the project and code

Panel members must submit their questions before the code defense. The questions will not be provided to the defending student in advance.

During the defense, defending students may use only:

- The terminal
- A comment-free version of their script file

Defending students may not use notes or other materials.

Participation in the assigned code defense is worth 10% of the project grade.

Defending students will be graded on:

- Thorough understanding of their code
- Bash programming techniques

Panel members will be graded on:

- Quality of submitted questions
- Active participation during the defense
