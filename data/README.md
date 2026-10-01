# Data

본 프로젝트는 경기도 카드 소비 데이터와 경기도 소비자물가지수(CPI)를 사용합니다.

원본 데이터 파일은 저장소에 포함하지 않습니다.

## 카드 소비 원자료

`01_main_did.do`에서 사용하는 주요 변수:

- `ta_ymd`: 거래 일자
- `cty_rgn_no`: 시군구 식별 변수
- `card_tpbuz_nm_1`: 업종 대분류명
- `card_tpbuz_nm_2`: 업종 세부분류명
- `age`: 연령대 코드
- `amt`: 카드 매출액
- `cnt`: 결제건수

`02_sector_did.do`에서는 업종명 깨짐을 방지하기 위해 추가로 다음 변수를 사용합니다.

- `card_tpbuz_cd`: 업종 코드

연령대 코드는 코드에서 다음과 같이 사용합니다.

- `age == 3`: 20대
- `age == 4`: 30대
- `age == 5`: 40대
- `age == 6`: 50대

분석 기간은 2023년 6월 1일부터 2025년 4월 30일까지입니다.

## CPI 데이터

`03_real_spending_did.do`에서 다음 파일을 사용합니다.

```text
지출목적별_소비자물가지수_경기도_2022_2025.csv
```

코드는 해당 파일에서 `0 총지수` 행을 추출하여 월별 CPI 데이터로 변환합니다.

## Generated Files

분석 과정에서 다음과 같은 Stata 데이터 파일이 생성됩니다.

- `card_month_sector.dta`
- `card_month_total.dta`
- `card_month_total_balanced.dta`
- `card_month_sector_code.dta`
- `sector_did_result.dta`
- `sector_did_result.csv`
- `sector_did_result_no_may.dta`
- `sector_did_result_no_may.csv`
- `cpi_total.dta`

생성 파일은 재현 과정에서 만들어지는 중간·결과 데이터이므로 공개 저장소에 포함하지 않습니다.
