# Public Examples

Architecture를 노출하지 않는 독립 예제와 implementation-analysis automation을 제공합니다.

- [`axi_stream_stability_checker.sv`](axi_stream_stability_checker.sv): Stall 구간 payload stability assertion
- [`scoreboard_skeleton.sv`](scoreboard_skeleton.sv): Count와 data를 함께 검사하는 최소 scoreboard
- [`vivado_postroute_analysis/`](vivado_postroute_analysis/README.md): Timing · Routing/Congestion · Power를 반복 수집하는 Vivado Tcl audit toolset

전체 production RTL의 일부를 잘라 공개하지 않고, 동일한 engineering principle을 설명하는 독립 예제로 작성합니다. 실제 generated Vivado report는 내부 hierarchy와 net/cell name이 포함될 수 있어 public repository에 그대로 포함하지 않습니다.

