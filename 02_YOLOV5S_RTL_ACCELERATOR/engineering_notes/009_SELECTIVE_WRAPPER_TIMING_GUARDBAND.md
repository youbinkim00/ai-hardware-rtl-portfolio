# 009 — Selective Wrapper Timing Guardband

> **Status: Experimental / in progress.** 이 문서는 완료된 timing 결과를 주장하지 않고, ZCU104 full-AXI 설계에서 진행 중인 physical closure 방법을 기록합니다.

## Problem

Core 단독 검증과 구현이 가능하더라도 PS, DMA, FIFO와 AXI wrapper를 연결하면 배치·배선 조건이 바뀝니다. 이 사례에서는 full design routing이 정상 완료된 기준점을 확보했지만, 200 MHz setup timing은 아직 통과하지 못했습니다.

```text
Verified core
    + AXI control/data boundary
    + DMA/FIFO/PS interconnect
    → wider physical span and routing-dominated control paths
```

따라서 “core가 동작하므로 AXI를 붙여도 자동으로 timing이 맞는다”라고 가정하지 않고, full-design routed result를 별도의 physical baseline으로 관리합니다.

## What is official and what is project-specific?

| 구분 | 내용 |
|---|---|
| AMD documented flow | Routed DCP를 `read_checkpoint -incremental`로 읽고 matching cell/net의 placement와 routing을 재사용 |
| AMD documented directive | `RuntimeOptimized`는 reference WNS를, `TimingClosure`는 WNS 0을 목표로 동작 |
| AMD documented constraint | `set_max_delay`로 선택한 timing path의 최대 허용 지연을 지정 |
| Project engineering choice | 5.000 ns clock에서 선택한 wrapper endpoint만 4.800 ns로 제한 |
| Not an AXI requirement | 0.200 ns margin의 크기와 대상 register 선정 |
| Pending evidence | 수정 설계의 final routed WNS, reuse, DRC와 bitstream 결과 |

## Guardband semantics

전체 clock constraint는 그대로 5.000 ns, 즉 200 MHz입니다. 선택한 wrapper endpoint만 4.800 ns 안에 도달하도록 요구합니다.

| 실제 path delay | Nominal 5.000 ns | Guard 4.800 ns |
|---:|---:|---:|
| 4.70 ns | +0.30 ns, pass | +0.10 ns, pass |
| 4.90 ns | +0.10 ns, pass | −0.10 ns, guard fail |
| 5.10 ns | −0.10 ns, fail | −0.30 ns, fail |

즉 guard는 200 MHz 검사를 완화하거나 무시하지 않습니다. 선택한 경로에 더 엄격한 implementation margin을 부여합니다.

정확한 범위는 “wrapper 내부 조합논리만”이 아닙니다. 동일 clock에서 출발하여 선택한 wrapper register의 `D` 또는 `CE` pin에서 끝나는 모든 동기 경로이므로 core-to-wrapper 경로도 포함될 수 있습니다.

현재 audit에서는 selector가 515개 sequential cell과 1,030개의 `D/CE` endpoint를 선택했습니다. 대부분은 512-bit output register bank이며 나머지는 관련 frame/control register입니다. 현재 log에서는 path-segmentation critical warning을 발견하지 않았지만, 전체 개수 하나만으로 각 register family가 의도대로 포함됐다고 보장할 수는 없습니다. 따라서 최종 precheck는 data, valid, last와 frame-control family를 각각 집계해야 합니다.

## Sanitized XDC pattern

아래 코드는 개념을 보여주는 익명화 예제이며 실제 private hierarchy selector는 공개하지 않습니다.

```tcl
set pl_clk [get_clocks pl_clk]
set boundary_regs [get_cells -hier -regexp {.*output_(data|valid|last).*_reg.*}]
set boundary_pins [get_pins -of_objects $boundary_regs \
    -filter {REF_PIN_NAME == D || REF_PIN_NAME == CE}]

if {[llength $pl_clk] != 1} {
    error "Expected exactly one PL clock"
}
if {[llength $boundary_pins] == 0} {
    error "Wrapper guard selected no sequential endpoints"
}

set_max_delay 4.800 -from $pl_clk -to $boundary_pins
```

`-datapath_only`는 사용하지 않습니다. AMD UG903에 따르면 이 옵션을 사용하지 않은 `set_max_delay`는 해당 경로의 기존 minimum/hold requirement를 변경하지 않습니다. 또한 invalid startpoint 또는 endpoint는 path segmentation을 유발할 수 있으므로 selector가 clock과 sequential `D/CE` pin만 잡는지 확인합니다.

## Why the scope must remain selective

512-bit output bank 전체와 몇 개의 control register를 대상으로 하면 알려진 경계 문제에 구현 우선순위를 줄 수 있습니다. 그러나 congestion이 높은 설계에서는 너무 넓은 overconstraint가 다른 경로의 router effort를 빼앗을 수도 있습니다.

따라서 다음 원칙을 사용합니다.

- 전체 5.000 ns clock을 임의로 4.800 ns로 바꾸지 않음
- 경로 분석에서 routing 지연이 지배적인 endpoint만 대상으로 함
- register family별 target count를 별도로 확인
- `report_exceptions -coverage`와 `-ignored`로 적용 범위를 검증
- routed 결과가 악화되면 4.900 ns로 완화하거나 endpoint를 더 좁힘

## Incremental directive choice

Reference DCP 자체의 WNS가 음수일 때는 `RuntimeOptimized`보다 `TimingClosure`가 목적에 맞습니다.

| Directive | AMD documented target | 이 사례의 판단 |
|---|---|---|
| `RuntimeOptimized` | Reference DCP의 WNS, 높은 reuse 선호 | 빠른 비교에는 유용하지만 timing closure 최종 run에는 부적합 |
| `TimingClosure` | WNS 0, 실패 경로를 풀어 재최적화 | 현재 200 MHz closure 목적에 적합 |
| `Quick` | 가장 빠른 low-effort, non-timing-driven | 최종 closure에 부적합 |

Incremental DCP는 hard lock도, 두 DCP를 합치는 기능도 아닙니다. Vivado는 matching object의 물리 정보를 우선 재사용하지만 QoR 또는 routability를 위해 일부를 다시 배치·배선할 수 있습니다.

## Required evidence before calling it successful

```text
1. report_incremental_reuse
2. report_route_status: failed/unrouted/overlap = 0
3. nominal 5.000 ns setup and hold report
4. guard 4.800 ns path-group report
5. report_exceptions -coverage / -ignored
6. check_timing: unconstrained path 확인
7. DRC and methodology critical violations = 0
```

Guard가 실패하더라도 nominal 5.000 ns가 통과하면 200 MHz 사양은 만족한 것입니다. 다만 이 경우 “0.2 ns margin 확보”를 주장해서는 안 됩니다. Guard까지 통과하면 nominal 200 MHz도 자동으로 만족하지만, 문서에는 nominal과 guard 결과를 별도로 남깁니다.

## Official AMD references

- [UG904 — Running Incremental Place and Route](https://docs.amd.com/r/2023.1-English/ug904-vivado-implementation/Running-Incremental-Place-and-Route)
- [UG904 — Using Incremental Implementation](https://docs.amd.com/r/2023.1-English/ug904-vivado-implementation/Using-Incremental-Implementation)
- [UG835 — `read_checkpoint` and incremental directives](https://docs.amd.com/r/2023.1-English/ug835-vivado-tcl-commands/read_checkpoint)
- [UG835 — `set_max_delay`](https://docs.amd.com/r/2023.1-English/ug835-vivado-tcl-commands/set_max_delay)
- [UG903 — Maximum/minimum delay consequences](https://docs.amd.com/r/2023.1-English/ug903-vivado-using-constraints/Consequences-of-Setting-Maximum-Delay-or-Minimum-Delay-Constraints-on-a-Path)
- [UG903 — Path segmentation caution](https://docs.amd.com/r/2023.1-English/ug903-vivado-using-constraints/Path-Segmentation)
- [UG835 — `report_exceptions`](https://docs.amd.com/r/2023.1-English/ug835-vivado-tcl-commands/report_exceptions?contentId=5boFgTH_XpgUPXhIGpvxwQ)

## Engineering lesson

이 방법의 가치는 DCP나 guardband 자체에 있지 않습니다. 기능이 검증된 architecture를 무리하게 다시 쓰지 않고, full-system physical evidence로 문제 범위를 좁힌 뒤 작은 RTL 변경과 측정 가능한 constraint를 적용하고, nominal sign-off와 추가 margin을 분리해 판단하는 데 있습니다.
