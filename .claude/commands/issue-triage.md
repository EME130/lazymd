Triage GitHub issues for this repository. Argument: $ARGUMENTS

If a specific issue number is given:
1. Fetch the issue with `gh issue view <number>`
2. Read related code to understand the scope
3. Classify: bug / feature request / question / duplicate
4. Suggest labels and priority
5. Draft a response comment (show it, don't post without approval)

If no argument or "list":
1. Fetch open issues: `gh issue list --state open --limit 20`
2. Summarize each with: title, age, labels, and a quick assessment
3. Identify any that might be duplicates
4. Suggest priority ordering

Never post comments or close issues without explicit user approval.
