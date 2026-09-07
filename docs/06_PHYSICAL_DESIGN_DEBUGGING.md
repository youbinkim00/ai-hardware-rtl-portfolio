# Physical Design Debugging Case Study

## Baseline

ZCU104 full AXI design에서 다음 물리 baseline을 보존했습니다.

| Metric | Baseline |
|---|---:|
| Routing errors | 0 |
| Unrouted nets | 0 |
| Node overlaps | 0 |
| WNS | −0.262 ns |
| TNS | −215.215 ns |
| Failing endpoints | 2,492 |
| Hold slack | +0.001 ns |

이 baseline은 timing pass 결과가 아니라, routing이 정상적으로 완료된 상태에서 timing 원인을 좁히기 위한 물리적 기준입니다.

## Root-cause analysis

Worst path는 software configuration register에서 wide output packer register의 clock-enable로 이어졌습니다.

```text
32-bit output-count configuration
       ↓ validation and modulo logic
ARM decision
       ↓ high-fanout control path
wide output packer clock-enable
```

- Data path delay: 약 5.200 ns
- Logic levels: 16
- Routing delay share: 약 70.8%

## Minimal RTL correction

- ARM qualification을 AXI-Lite control boundary에서 수행
- 승인/거부 결과를 1-cycle pulse로 등록
- 실행 frame의 expected output count를 ARM 시 별도 register에 snapshot
- Output packer가 live configuration register를 직접 참조하지 않도록 분리

Core datapath, PE, feature-memory controller, requantization, DMA width와 Block Design topology는 변경하지 않았습니다.

## Avoiding stale generated netlists

Vivado Block Design의 module reference가 이전 OOC checkpoint를 재사용하면 source를 수정해도 전체 implementation이 100% 동일하게 보일 수 있습니다. 이를 방지하기 위해 다음을 확인했습니다.

1. Module reference update
2. BD target regeneration
3. 해당 OOC synthesis run reset/relaunch
4. 새 OOC netlist에서 수정 register/cell 존재 확인
5. 그 후에만 full-design incremental implementation 실행

## Incremental implementation

Routing 성공 post-route DCP를 reference checkpoint로 사용합니다. 동일한 logic은 기존 placement/routing을 최대한 재사용하고, 변경된 logic과 영향을 받은 주변 경로만 다시 최적화합니다. DCP 자체는 공개하지 않고 hash와 요약 결과만 기록합니다.

## Result table

현재 implementation 완료 후 아래 표를 갱신합니다.

| Metric | Baseline | Modified |
|---|---:|---:|
| Routing errors | 0 | Pending |
| WNS | −0.262 ns | Pending |
| TNS | −215.215 ns | Pending |
| Failing endpoints | 2,492 | Pending |
| LUT | Baseline | Pending |
| FF | Baseline | Pending |

