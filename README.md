# Decentralised Local Government Budget Auditing

A Clarity smart contract enabling local governments to register, create budgets, allocate items, record expenditures, authorize auditors, submit audits, verify expenditures, and approve audit results.

## ✨ Features
- Register government entities and auditors
- Create budgets with deadlines and itemized allocations
- Record and track expenditures per item
- Submit and approve audits with scoring and recommendations
- Verify expenditures by authorized auditors
- Read-only query endpoints for all core records

## 🧩 Contract
- Path: `contracts/Decentralised-Local-Government-Budget-Auditing.clar`
- Compatible with Clarinet
- Uses `stacks-block-height` and `get-stacks-block-info`

## 🚀 Quickstart

```bash
clarinet console
```

```bash
clarinet check
```

Normalize line endings on Windows PowerShell:

```powershell
(Get-Content "contracts/Decentralised-Local-Government-Budget-Auditing.clar" -Raw).Replace("`r`n", "`n") | Set-Content "contracts/Decentralised-Local-Government-Budget-Auditing.clar" -NoNewline
```

## 🛠️ Public Functions

- register-government(name, jurisdiction) -> ok
- register-auditor(name, certification) -> ok
- create-budget(title, total-amount, deadline) -> budget-id
- add-budget-item(budget-id, item-id, description, allocated-amount, category) -> ok
- finalize-budget(budget-id) -> ok
- record-expenditure(budget-id, expenditure-id, item-id, amount, recipient, description) -> ok
- submit-audit(budget-id, findings, recommendation, score) -> audit-id
- verify-expenditure(budget-id, expenditure-id) -> ok
- approve-audit(audit-id) -> ok (owner only)
- update-auditor-reputation(auditor, new-score) -> ok (owner only)

## 🔎 Read-only Functions

- get-budget(budget-id)
- get-budget-item(budget-id, item-id)
- get-audit(audit-id)
- get-government-entity(government)
- get-auditor(auditor)
- get-expenditure(budget-id, expenditure-id)
- get-next-budget-id()
- get-next-audit-id()
- get-contract-owner()

## 📦 Example Usage

```clarity
(register-government "City Alpha" "Region-1")
```

```clarity
(register-auditor "Alice" "CPA-123")
```

```clarity
(create-budget "FY2026 Capital" u1000000 u120000)
```

```clarity
(add-budget-item u1 u1 "Road Repairs" u300000 "infrastructure")
```

```clarity
(finalize-budget u1)
```

```clarity
(record-expenditure u1 u1 u1 u25000 'SP3FBR2... "Asphalt batch 1")
```

```clarity
(submit-audit u1 "Findings text" "Recommendations" u95)
```

```clarity
(verify-expenditure u1 u1)
```

```clarity
(approve-audit u1)
```

## ✅ Development
- Run local checks: `clarinet check`
- Run tests: `npm install && npm test`

## 📄 License
MIT
