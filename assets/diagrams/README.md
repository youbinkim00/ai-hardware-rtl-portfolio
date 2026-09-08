# Original Portfolio Diagrams

이 디렉터리의 SVG는 이 포트폴리오를 위해 새로 제작한 원본 시각 자료입니다. 논문 또는 다른 저장소의 그림을 복사하지 않았으며, 공개 자료를 조사해 다음 시각 원칙만 참고했습니다.

- architecture, verification, deployment를 한 그림에 무리하게 합치지 않고 목적별로 분리
- control plane과 data plane을 색상과 레인으로 구분
- 단순 작업 순서가 아니라 artifact와 acceptance gate를 함께 표시
- 제안 구조와 일반 배경 개념도를 캡션에서 구분

기술 용어와 연결 관계는 이 저장소의 공개 문서 및 다음 공개 프로젝트·공식 문서를 교차 참고했습니다.

- [Microsoft Brainsmith](https://github.com/microsoft/brainsmith)
- [FEATHER](https://github.com/maeri-project/FEATHER)
- [AMD AXI DMA PG021](https://docs.amd.com/r/en-US/pg021_axi_dma)

모든 SVG는 브라우저에서 확대해도 선명하며, 텍스트 편집기로 색상·문구·좌표를 수정할 수 있습니다.

## Diagram index

- `portfolio_map.svg`: portfolio section map
- `whole_stack.svg`: software-to-deployment acceptance chain
- `public_system_boundary.svg`: public AXI/DMA system boundary
- `project_scope_pipeline.svg`: project verification stages
- `timing_closure_case_study.svg`: legal-route DCP, local guardband와 dual sign-off flow
