# 006 — Vivado OOC and Module-Reference Pitfalls

## The stale-netlist problem

Block Design에 RTL module reference가 들어가면 top source를 수정해도 기존 OOC checkpoint가 up-to-date로 판단될 수 있습니다. 이 상태에서 incremental implementation을 실행하면 수정 전 cell/net이 100% 재사용되는 것처럼 보일 수 있습니다.

## Correct refresh sequence

```text
update module reference
→ validate/save Block Design
→ regenerate BD targets
→ recreate/reset related OOC run
→ launch OOC synthesis
→ inspect synthesized cells
→ run full top synthesis/implementation
```

Timestamp만으로 판단하지 않고 새로 추가한 register/cell이 OOC netlist에 존재하는지 확인해야 합니다.

## Acceptance rule

- Source hash changed
- Target OOC run completed after source change
- Modified cell exists in new OOC DCP
- Full implementation reuse is high but not blindly 100% for changed hierarchy

