# Original Portfolio Diagrams

이 디렉터리의 SVG는 이 포트폴리오를 위해 제작한 **개념 설명용 vector diagram**입니다. 실제 Vivado 구조를 공개할 수 있는 항목은 `../evidence/`의 tool screenshot을 우선 사용합니다.

시각 원칙:

- architecture, verification, deployment를 한 그림에 무리하게 합치지 않고 목적별로 분리
- 동일 단계의 card는 동일 baseline/height/spacing을 유지
- PRIMARY 항목은 크기를 깨뜨리지 않고 border/accent로 강조
- control plane과 data plane을 색상과 레인으로 구분
- 단순 작업 순서가 아니라 artifact와 acceptance gate를 함께 표시
- 실제 tool evidence와 conceptual abstraction을 캡션에서 구분

## Diagram index

- `portfolio_map.svg` — portfolio section map; 3개 card baseline/height 정렬
- `whole_stack.svg` — software-to-deployment closed engineering loop; 7개 stage 동일 card geometry
- `public_system_boundary.svg` — conceptual AXI boundary; primary evidence는 `../evidence/zcu104_axi_dma_block_design.png`
- `project_scope_pipeline.svg` — project verification stages; RTL primary stage는 크기가 아닌 accent로 강조
- `timing_closure_case_study.svg` — legal-route DCP, local guardband와 dual sign-off flow; 6개 step 동일 geometry

실제 verification/integration screenshot:

- `../evidence/axi_vip_block_design.png`
- `../evidence/zcu104_axi_dma_block_design.png`

- `yolov5s_software_to_rtl_pipeline.svg` — QAT · mixed precision · integer export · standalone reference · RTL scoreboard flow
