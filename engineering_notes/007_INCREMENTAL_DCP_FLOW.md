# 007 — Incremental DCP for Timing Closure

## What an incremental checkpoint is

Incremental implementation은 이전 DCP를 고정된 최종 결과로 복사하는 기능이 아닙니다. 변경되지 않은 cell의 placement/routing을 최대한 재사용하고 변경된 영역을 다시 최적화하는 출발점입니다.

## Good reference criteria

- Route completed
- Routing errors = 0
- Unrouted nets = 0
- Node overlaps = 0
- Current functional RTL과 동일한 interface/constraint
- DCP hash와 source hash 기록

Timing이 약간 실패했더라도 legal route라면 특정 critical path 수정 실험의 reference로 사용할 수 있습니다. 단, 이를 timing-pass baseline이라고 부르면 안 됩니다.

## What to compare

| Item | Why |
|---|---|
| Cell/net reuse | Reference가 실제 적용됐는지 확인 |
| WNS/TNS | Worst path뿐 아니라 전체 violation 변화 확인 |
| Failing endpoints | 문제 확산 여부 확인 |
| Route status | Timing 개선 과정에서 legality가 깨지지 않았는지 확인 |
| Utilization delta | 작은 RTL 수정이 예상 밖 복제를 만들었는지 확인 |
| Worst path endpoints | 원래 경로가 제거됐는지 확인 |

