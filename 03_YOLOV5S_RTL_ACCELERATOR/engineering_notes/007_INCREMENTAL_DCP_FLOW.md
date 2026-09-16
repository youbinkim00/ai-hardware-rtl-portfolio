# 007 — Incremental DCP for Timing Closure

## What an incremental checkpoint is

Incremental implementation은 이전 DCP를 고정된 최종 결과로 복사하거나 두 netlist를 합치는 기능이 아닙니다. 현재 netlist와 reference DCP를 비교하여 matching cell/net의 placement와 routing을 최대한 재사용하고, 변경된 영역을 다시 최적화하는 출발점입니다.

AMD UG904에 따르면 처음 재사용된 물리 정보도 QoR 또는 routability에 도움이 된다면 구현 과정에서 폐기될 수 있습니다. 따라서 “DCP를 넣으면 배치·배선이 완전히 잠긴다”거나 “같은 결과가 보장된다”라고 설명하면 안 됩니다.

```tcl
# Sanitized non-project flow concept
open_run synth_1
read_checkpoint -incremental -directive TimingClosure ./reference_legal_route.dcp
place_design
phys_opt_design
route_design
report_incremental_reuse
```

## Good reference criteria

- Route completed
- Routing errors = 0
- Unrouted nets = 0
- Node overlaps = 0
- Current functional RTL과 동일한 interface/constraint
- DCP hash와 source hash 기록

Timing이 약간 실패했더라도 legal route라면 특정 critical path 수정 실험의 reference로 사용할 수 있습니다. 단, 이를 timing-pass baseline이라고 부르면 안 됩니다.

## Directive selection

| Directive | AMD documented target | 적합한 용도 |
|---|---|---|
| `RuntimeOptimized` | Reference DCP의 WNS, reuse를 더 장려 | 이미 QoR가 만족스럽고 실행시간과 재현성이 우선인 경우 |
| `TimingClosure` | WNS 0, 실패 경로를 풀어 재최적화 | Reference의 WNS가 음수이고 timing pass가 목표인 경우 |
| `Quick` | Low-effort, non-timing-driven | 빠른 탐색용 |

이 프로젝트의 legal-route reference WNS는 −0.262 ns입니다. 따라서 최종 200 MHz closure run에서 `RuntimeOptimized`를 사용하면 reference의 음수 WNS 수준을 목표로 할 수 있으므로, `TimingClosure`가 목적에 더 정확히 맞습니다. `TimingClosure`도 통과를 보장하는 옵션은 아니며 WNS 0을 목표로 더 많은 runtime을 사용하는 모드입니다.

AMD의 `-auto_incremental` 기준은 별도입니다. UG904의 automatic flow는 reference WNS ≥ −0.250 ns, cell match ≥ 94%, net match ≥ 90%를 평가합니다. 현재 reference는 이 automatic WNS 기준보다 0.012 ns 낮지만, 수동 `-incremental` reference로 사용하는 것은 가능합니다. 이를 automatic 또는 timing-golden baseline이라고 표현하지 않습니다.

## What to compare

| Item | Why |
|---|---|
| Cell/net reuse | Reference가 실제 적용됐는지 확인 |
| WNS/TNS | Worst path뿐 아니라 전체 violation 변화 확인 |
| Failing endpoints | 문제 확산 여부 확인 |
| Route status | Timing 개선 과정에서 legality가 깨지지 않았는지 확인 |
| Utilization delta | 작은 RTL 수정이 예상 밖 복제를 만들었는지 확인 |
| Worst path endpoints | 원래 경로가 제거됐는지 확인 |

## Official AMD references

- [UG904 — Running Incremental Place and Route](https://docs.amd.com/r/2023.1-English/ug904-vivado-implementation/Running-Incremental-Place-and-Route)
- [UG904 — Using Incremental Implementation](https://docs.amd.com/r/2023.1-English/ug904-vivado-implementation/Using-Incremental-Implementation)
- [UG904 — Automatic Incremental](https://docs.amd.com/r/2023.1-English/ug904-vivado-implementation/Automatic-Incremental?contentId=7Y7SDnAoOmrL8Kp4t8LZqg)
- [UG835 — `read_checkpoint`](https://docs.amd.com/r/2023.1-English/ug835-vivado-tcl-commands/read_checkpoint)

실제 wrapper 경계에 추가 구현 여유를 주는 방법은 [Selective Wrapper Timing Guardband](009_SELECTIVE_WRAPPER_TIMING_GUARDBAND.md)에 별도로 정리했습니다.
