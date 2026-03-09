# Auto-Label JIRA Bugs

You are helping automate bug labeling for the networking team.

## Usage

- `/label-bugs` - Analyze and apply labels to unlabeled bugs (uses MCP JIRA server)
- `/label-bugs --dry-run` - Analyze bugs and show what labels would be applied WITHOUT actually applying them
- `/label-bugs --api` - Use Python API instead of MCP JIRA server (fallback mode)
- `/label-bugs --api --dry-run` - Use Python API in dry-run mode

## Mode Selection

**Default (MCP Mode)**: Uses the MCP JIRA server tools (`mcp__jira-atlassian__*`)

**API Mode** (`--api` flag): Falls back to Python script using direct JIRA API via `jira-scripts/network_bugs_overview`

If the user specifies `--api`, you MUST use the Python script instead of MCP tools for both fetching bugs and applying labels.

## Dry Run Mode

If the user invokes this command with `--dry-run`, `dry-run`, or `-n`:
- Perform all analysis steps normally
- Show what label would be applied to each bug
- **DO NOT** apply any labels to JIRA
- **DO NOT** ask user questions (no AskUserQuestion tool calls)
- Just analyze and display results for all bugs, including medium and low confidence ones
- Clearly indicate in the output that this is a dry run
- Mark items with `[DRY RUN]` prefix in the summary

## Your Task

1. **Read the label mapping** from `jira-scripts/area_labels.csv`:
   - First column: Feature/area description
   - Second column: Label to apply

2. **Fetch unlabeled bugs** from JIRA:

   **MCP Mode (default - when --api is NOT specified)**:
   - Use the `mcp__jira-atlassian__jira_search` tool
   - Use this JQL query:
   ```
   project = OCPBUGS AND component in ("Networking / openshift-sdn", "Networking / ovn-kubernetes", "Networking / cloud-network-config-controller", "Networking / ingress-node-firewall", "Networking / cluster-network-operator", "Networking / network-tools") AND resolution = Unresolved AND (assignee = "bbennett@redhat.com" OR assignee is EMPTY) ORDER BY Rank DESC
   ```
   - Request fields: `summary,description,labels,components,issuelinks`

   **API Mode (when --api is specified)**:
   - Use the Bash tool to run: `cd jira-scripts && ./network_bugs_overview --query "YOUR_JQL_QUERY_HERE"`
   - Use the same JQL query as above
   - The script will output detailed bug information including ID, summary, description, labels, components, issue links, and comments

3. **For each bug without an area label**:
   - **In MCP mode**: Read additional details using `mcp__jira-atlassian__jira_get_issue` if needed
   - **In API mode**: All details are already available from step 2
   - **Check if it's a backport**: If the bug has dependencies (depends on another bug), it's a backport → apply `SDN:Backport` label
   - Otherwise, analyze the content and determine which ONE label from the CSV best fits
   - **Confidence levels**:
     - **High confidence** (>80% sure): Automatically apply the label
     - **Medium confidence** (40-80% sure): Present top 2-3 candidates to user for selection
     - **Low confidence** (<40% sure): Ask user to review and choose

4. **For medium and low confidence bugs** (SKIP THIS STEP ENTIRELY in dry-run mode):
   - **In normal mode**: After displaying the summary, use the AskUserQuestion tool to ask the user which label to apply for each bug. Present the top 2-3 alternatives as options.
   - **In dry-run mode**: DO NOT use AskUserQuestion. Just display the analysis with proposed label and alternatives.
   - **IMPORTANT**: Always include a "Skip/Defer" option that allows the user to skip applying any label to the bug
   - **CRITICAL**: The "Skip/Defer" option MUST ALWAYS be option 1 (the first option) so users can quickly press 1 to skip bugs they want to defer
   - **In the question text**: Include a brief summary of the bug description (2-3 sentences max) and a clickable link to the bug
   - **Format**: "OCPBUGS-XXXXX: [Brief summary of the issue]. Link: https://issues.redhat.com/browse/OCPBUGS-XXXXX"
   - Example question: "OCPBUGS-64932: Time drift during Chrony configuration causes ovnkube-controller certificate to become invalid, causing pods to crash. The certificate NotBefore time is ahead of worker node time. Link: https://issues.redhat.com/browse/OCPBUGS-64932 - Which label should be applied?"

5. **Apply the labels** to JIRA (skip this step if in dry-run mode):
   - **In MCP mode**: Use `mcp__jira-atlassian__jira_update_issue` to apply labels
   - **In API mode**: Use the Bash tool to run: `cd jira-scripts && ./network_bugs_overview --label-bug OCPBUGS-XXXXX --label "SDN:LabelName"`

6. **Display analysis results** using this standardized format for EACH bug:

   ```
   OCPBUGS-12345 - Bug title here (truncated to 80 chars if needed)
   - Proposed label: SDN:OVNK:EgressIP
   - Confidence: 95%
   - Reasoning: Brief explanation of why this label was chosen
   - URL: https://issues.redhat.com/browse/OCPBUGS-12345
   ```

   For medium and low confidence bugs, also show:
   ```
   - Top alternatives: SDN:Platform:OVNK, SDN:OVNK:AdminNetworkPolicy
   - URL: https://issues.redhat.com/browse/OCPBUGS-12345
   ```

7. **Print final summary** at the end grouped by confidence level:

   Normal mode:
   ```
   🟢 High confidence (auto-applied):
   OCPBUGS-12345 - Bug title here
   - Proposed label: SDN:OVNK:EgressIP
   - Confidence: 95%
   - Reasoning: Explicitly about EgressIP failover issues with IPv6
   - URL: https://issues.redhat.com/browse/OCPBUGS-12345

   OCPBUGS-12346 - Another bug title
   - Proposed label: SDN:Platform:CNO
   - Confidence: 85%
   - Reasoning: CNO configuration and deployment issue
   - URL: https://issues.redhat.com/browse/OCPBUGS-12346

   🟡 Medium confidence (review recommended):
   OCPBUGS-12347 - Third bug
   - Proposed label: SDN:OVNK:NetworkPolicy
   - Confidence: 70%
   - Reasoning: Network policy enforcement behavior
   - Top alternatives: SDN:Platform:OVNK, SDN:OVNK:AdminNetworkPolicy
   - URL: https://issues.redhat.com/browse/OCPBUGS-12347

   🔴 Low confidence (user input needed):
   OCPBUGS-12349 - Fifth bug
   - Proposed label: SDN:Tooling
   - Confidence: 35%
   - Reasoning: May be related to must-gather or debugging tools
   - Top alternatives: SDN:Platform:CNO, SDN:Metrics
   - URL: https://issues.redhat.com/browse/OCPBUGS-12349

   User selected:
   OCPBUGS-12350 - Sixth bug - SDN:OVNK:EgressIP (user confirmed)
   - URL: https://issues.redhat.com/browse/OCPBUGS-12350

   OCPBUGS-12351 - Seventh bug - Skipped (no label applied)
   - URL: https://issues.redhat.com/browse/OCPBUGS-12351
   ```

   Dry-run mode (same format with [DRY RUN] prefix, no user interaction):
   ```
   🟢 High confidence:
   [DRY RUN] OCPBUGS-12345 - Bug title here
   - Proposed label: SDN:OVNK:EgressIP
   - Confidence: 95%
   - Reasoning: Explicitly about EgressIP failover issues with IPv6
   - URL: https://issues.redhat.com/browse/OCPBUGS-12345

   🟡 Medium confidence:
   [DRY RUN] OCPBUGS-12347 - Third bug
   - Proposed label: SDN:OVNK:NetworkPolicy
   - Confidence: 70%
   - Reasoning: Network policy enforcement behavior
   - Top alternatives: SDN:Platform:OVNK, SDN:OVNK:AdminNetworkPolicy
   - URL: https://issues.redhat.com/browse/OCPBUGS-12347

   🔴 Low confidence:
   [DRY RUN] OCPBUGS-12349 - Fifth bug
   - Proposed label: SDN:Tooling
   - Confidence: 35%
   - Reasoning: May be related to must-gather or debugging tools
   - Top alternatives: SDN:Platform:CNO, SDN:Metrics
   - URL: https://issues.redhat.com/browse/OCPBUGS-12349
   ```

## Important Rules

- **Use MCP JIRA server tools by default** (`mcp__jira-atlassian__*`). Only use Python scripts when `--api` flag is specified
- Each bug gets **exactly ONE** area label
- Backports always get `SDN:Backport` (check bug dependencies/links)
- If a bug already has an area label (any label starting with "SDN:" or "SDN-"), skip it
- **In dry-run mode**: NEVER use AskUserQuestion tool - just analyze and display all results
- **In normal mode**: Be conservative - when in doubt, ask the user rather than applying wrong label
- **Always provide a "Skip/Defer" option** when asking the user about medium/low confidence bugs (normal mode only)
- **The "Skip/Defer" option MUST be option 1 (first option) in every user question dialog** so users can quickly press 1 to skip
- **In AskUserQuestion dialogs**: Include a brief bug summary (2-3 sentences) and a link to the bug (https://issues.redhat.com/browse/OCPBUGS-XXXXX)
- Consider all available context: title, description, affected components, issue links
- Use the standardized output format for each bug (key, title, proposed label, confidence %, reasoning)
- **ALWAYS include the bug URL as the LAST item** for each bug in the format: `- URL: https://issues.redhat.com/browse/OCPBUGS-XXXXX`
- Group bugs by confidence level in the summary: high, medium, low, and user selected (in normal mode)
- In dry-run mode, group by: high, medium, and low confidence only (no "user selected" section)
- Show emoji once at the beginning of each confidence group: 🟢 🟡 🔴
- For medium and low confidence bugs, show the top 2-3 alternative labels considered
- Skip groups that have no bugs (e.g., if no low confidence bugs, don't show that section)
- Track skipped bugs separately in the summary
