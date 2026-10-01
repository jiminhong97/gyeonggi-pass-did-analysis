# Gyeonggi Pass DID Analysis

The 경기패스의 청년 우대 환급 혜택이 청년층의 카드 소비에 미친 상대적 변화를 분석한 Difference-in-Differences(DID) 프로젝트입니다.

## 프로젝트 소개

본 프로젝트는 경기도 카드 소비 데이터를 활용하여 The 경기패스 시행 전후 청년층의 소비 변화가 일반 연령층과 비교해 어떻게 달라졌는지 분석한 응용계량경제학 팀 프로젝트입니다.

처치집단은 20·30대, 비교집단은 40·50대로 설정하였으며, 2023년 6월부터 2025년 4월까지의 23개월 데이터를 시군구-월-청년여부 단위의 패널로 재구성하였습니다. 메인 DID 분석 외에도 정책 시행 전 평행추세 확인, 업종별 분석, 정책 시행월 제외 강건성 분석, 선택소비 분석, CPI 조정 실질 매출 분석을 수행하였습니다.

## 연구 설계

- 분석 기간: 2023.06 ~ 2025.04
- 정책 시행 시점: 2024.05
- 처치집단: 경기도 20·30대
- 비교집단: 경기도 40·50대
- 전체 소비 패널: 16개 시군구 × 23개월 × 2개 집단
- 전체 소비 관측치: 736개
- 업종별 패널: 16개 시군구 × 23개월 × 2개 집단 × 9개 업종
- 업종별 관측치: 6,624개
- 종속변수: 로그 카드매출액, 로그 결제건수
- 추정 방식: unit fixed effects + month fixed effects DID

기본 DID 회귀식은 다음 구조를 사용합니다.

```text
Outcome_it = β0 + β1 DID_it + Unit FE + Month FE + ε_it
```

Stata에서는 다음과 같이 추정합니다.

```stata
regress ln_amt did i.unit_id i.mdate
regress ln_cnt did i.unit_id i.mdate
```

## 분석 흐름

### 1. Main DID

`01_main_did.do`

- 원본 CSV 병합 및 분석 기간 필터링
- 20·30대와 40·50대 집단 구성
- 월 변수 및 정책 시행 이후 변수 생성
- 시군구-월-청년여부 패널 구축
- 23개월 모두 관측되는 시군구만 남겨 균형 패널 구성
- 전체 카드매출액 및 결제건수 DID
- 정책 시행 전 선형 추세 검정
- 청년층·일반층 소비 추세 시각화

### 2. Sector-Level DID & Robustness Checks

`02_sector_did.do`

업종코드 첫 글자를 이용하여 다음 9개 업종으로 재분류합니다.

- 공공기업단체
- 공연전시
- 미디어통신
- 생활서비스
- 소매유통
- 여가오락
- 음식
- 의료건강
- 학문교육

주요 분석:

- 9개 업종별 카드매출액 DID
- 9개 업종별 결제건수 DID
- 업종별 DID 결과표 자동 생성
- 2024년 5월 정책 시행월 제외 강건성 분석
- 음식·여가오락·공연전시·소매유통을 묶은 선택소비 분석
- 정책 전후 평균 비교
- 선택소비 추세 시각화

### 3. CPI-Adjusted Real Spending DID

`03_real_spending_did.do`

- 경기도 소비자물가지수(CPI) 총지수 월별 데이터 구축
- 명목 카드매출액을 실질 카드매출액으로 변환
- 전체 소비 실질 매출 DID
- 선택소비 실질 매출 DID
- 명목 결과와 CPI 조정 결과 비교

실질 카드매출액은 다음과 같이 계산합니다.

```text
Real Card Spending = Nominal Card Spending / CPI × 100
```

## 평행추세 확인

정책 시행 이전 기간만을 이용하여 청년층과 비교집단 간 선형 추세 차이를 확인합니다.

```stata
gen t = mdate - ym(2023, 6) + 1
gen youth_t = youth * t

regress ln_amt youth t youth_t if mdate < ym(2024, 5)
regress ln_cnt youth t youth_t if mdate < ym(2024, 5)
```

`youth_t` 계수가 통계적으로 유의한지 확인하여 정책 시행 전 두 집단의 추세 차이가 뚜렷한지 점검합니다.

## 주요 결과

전체 소비 분석에서 The 경기패스 시행 이후 청년층의 카드 소비가 비교집단보다 증가했다는 근거는 확인되지 않았습니다.

- 로그 카드매출액 DID 계수: 약 -0.0263
- 카드매출액 상대 변화: 약 -2.6%
- 로그 결제건수 DID 계수: 약 -0.0332
- 결제건수 상대 변화: 약 -3.3%

일부 업종에서는 상대적 감소가 통계적으로 유의하게 나타났으며, 공연전시와 같은 일부 업종에서는 양의 계수가 나타났지만 통계적으로 유의하지 않았습니다.

이 결과는 The 경기패스의 전체 정책 효과를 의미하지 않습니다. 비교집단 역시 정책 대상이 될 수 있으므로, 본 분석은 청년층의 더 높은 환급 혜택에 따른 **상대적 소비 변화**를 분석한 결과입니다.

## Repository Structure

```text
.
├── README.md
├── .gitignore
├── data/
│   └── README.md
└── stata/
    ├── 01_main_did.do
    ├── 02_sector_did.do
    └── 03_real_spending_did.do
```

## 실행 순서

분석은 다음 순서로 실행합니다.

```text
01_main_did.do
    ↓
card_month_total_balanced.dta

02_sector_did.do
    ↓
card_month_sector_code.dta

03_real_spending_did.do
    ↓
CPI-adjusted DID analysis
```

## 데이터 준비

원본 카드 소비 데이터와 CPI 데이터는 저장소에 포함하지 않습니다.

코드 실행 전 각 Stata 파일 상단의 로컬 경로를 사용자 환경에 맞게 수정해야 합니다.

예:

```stata
local raw "C:/YOUR_PATH/card_data"
local out "C:/YOUR_PATH/analysis"
```

필요한 데이터 구조는 `data/README.md`에서 확인할 수 있습니다.

## 해석 시 참고사항

- 본 프로젝트의 통제집단은 완전한 비수혜 집단이 아닙니다.
- 평행추세 확인은 event-study가 아니라 정책 시행 전 `Youth × linear time trend` 검정입니다.
- 회귀식은 clustered 또는 robust standard error를 별도로 적용하지 않은 기본 `regress` 결과입니다.
- 정책 시행월 제외 분석은 표준오차 보정이 아닌 specification robustness check입니다.
- 최종 분석은 23개월 모두 관측되는 16개 시군구에 한정됩니다.

## 프로젝트 정보

- 수행 형태: 응용계량경제학 팀 프로젝트
- 분석 도구: Stata
- 분석 방법: Difference-in-Differences, Fixed Effects, Pre-trend Check, Robustness Analysis
