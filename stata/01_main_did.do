clear all
set more off

* 원본 CSV 파일들이 들어 있는 폴더
local raw "C:/Users/LG/Desktop/지민/수업자료/응용계량경제학/팀플/카드소비 데이터"

* 분석용 dta 저장 폴더
local out "C:/Users/LG/Desktop/지민/수업자료/응용계량경제학/팀플/카드소비 데이터/분석용"

* 저장 폴더가 없으면 생성
capture mkdir "`out'"

* 폴더 이동
cd "`raw'"

* 현재 폴더 확인
pwd

* 폴더 안 파일 확인
dir

* csv 파일 목록 가져오기
local files : dir "`raw'" files "*.csv"

* csv 파일 개수 확인
local nfiles : word count `files'

display "CSV 파일 개수 = `nfiles'"

if `nfiles' == 0 {
    display "CSV 파일을 찾지 못함. raw 경로 또는 파일 확장자를 확인해야 함."
    exit
}

* 잡힌 파일명 확인
foreach f of local files {
    display "`f'"
}



****************************************************
* The 경기패스 카드소비 DID 분석용 데이터 구축
* 모든 CSV 파일을 한 폴더에 넣은 상태에서 실행
****************************************************

clear all
set more off

****************************************************
* 1. 폴더 설정
****************************************************

local raw "C:/Users/LG/Desktop/지민/수업자료/응용계량경제학/팀플/카드소비 데이터"
local out "C:/Users/LG/Desktop/지민/수업자료/응용계량경제학/팀플/카드소비 데이터/분석용"

capture mkdir "`out'"

cd "`raw'"
pwd

****************************************************
* 2. CSV 파일 목록 불러오기
****************************************************

local files : dir "`raw'" files "*.csv"
local nfiles : word count `files'

display "CSV 파일 개수 = `nfiles'"

if `nfiles' == 0 {
    display "CSV 파일을 찾지 못함. raw 경로를 다시 확인할 것."
    exit
}

****************************************************
* 3. 파일을 하나씩 처리해서 작게 만든 뒤 누적 저장
****************************************************

local first = 1
local done = 0

foreach f of local files {

    display "========================================"
    display "처리 중인 파일: `f'"
    display "========================================"

    import delimited using "`raw'/`f'", clear varnames(1) encoding("utf-8")

    ************************************************
    * 필요한 변수가 있는지 확인
    ************************************************

    foreach v in ta_ymd cty_rgn_no card_tpbuz_nm_1 card_tpbuz_nm_2 age amt cnt {
        capture confirm variable `v'
        if _rc {
            display "오류: `f' 파일에 `v' 변수가 없음"
            describe
            exit
        }
    }

    ************************************************
    * 필요한 변수만 남김
    ************************************************

    keep ta_ymd cty_rgn_no card_tpbuz_nm_1 card_tpbuz_nm_2 age amt cnt

    ************************************************
    * 숫자 변수 변환
    ************************************************

    foreach v in ta_ymd cty_rgn_no age amt cnt {
        capture confirm numeric variable `v'
        if _rc {
            destring `v', replace ignore(",")
        }
    }

    ************************************************
    * 메인 분석 기간
    * 2023년 6월 ~ 2025년 4월
    ************************************************

    keep if ta_ymd >= 20230601
    keep if ta_ymd <= 20250430

    count
    if r(N) == 0 {
        display "분석 기간 밖 파일이라 건너뜀: `f'"
        continue
    }

    ************************************************
    * 연령집단 설정
    * age 3 = 20대
    * age 4 = 30대
    * age 5 = 40대
    * age 6 = 50대
    ************************************************

    keep if age == 3 | age == 4 | age == 5 | age == 6

    count
    if r(N) == 0 {
        display "분석 대상 연령 없음. 건너뜀: `f'"
        continue
    }

    gen youth = .
    replace youth = 1 if age == 3 | age == 4
    replace youth = 0 if age == 5 | age == 6

    ************************************************
    * 월 변수 생성
    ************************************************

    gen year = floor(ta_ymd / 10000)
    gen month = floor((ta_ymd - year * 10000) / 100)

    gen mdate = ym(year, month)
    format mdate %tm

    ************************************************
    * 정책 시행 이후 변수
    ************************************************

    gen post = 0
    replace post = 1 if mdate >= ym(2024, 5)

    gen did = youth * post

    ************************************************
    * 업종 변수명 정리
    ************************************************

    rename card_tpbuz_nm_1 sector1
    rename card_tpbuz_nm_2 sector2

    ************************************************
    * 파일 하나를 월별 분석 단위로 축소
    ************************************************

    collapse (sum) amt cnt, by(cty_rgn_no mdate youth post did sector1)

    ************************************************
    * 누적 저장
    ************************************************

    if `first' == 1 {
        save "`out'/card_month_sector.dta", replace
        local first = 0
    }
    else {
        append using "`out'/card_month_sector.dta"
        save "`out'/card_month_sector.dta", replace
    }
 
    local done = `done' + 1
    display "완료된 파일 수 = `done'"
}

****************************************************
* 4. 최종 데이터 확인
****************************************************

use "`out'/card_month_sector.dta", clear

describe
count
tab mdate
tab cty_rgn_no
tab youth
tab sector1

save "`out'/card_month_sector.dta", replace



****************************************************
* 분석용 폴더로 이동
****************************************************

clear all
set more off

cd "C:/Users/LG/Desktop/지민/수업자료/응용계량경제학/팀플/카드소비 데이터/분석용"

****************************************************
* 전체 소비 분석용 데이터 만들기
****************************************************

use "card_month_sector.dta", clear

collapse (sum) amt cnt, by(cty_rgn_no mdate youth post did)

gen ln_amt = ln(amt + 1)
gen ln_cnt = ln(cnt + 1)

egen unit_id = group(cty_rgn_no youth)

save "card_month_total.dta", replace

describe
count
tab mdate
tab cty_rgn_no
tab youth

****************************************************
* 균형 패널 확인 및 저장
****************************************************

use "card_month_total.dta", clear

bysort cty_rgn_no mdate: gen month_one = _n == 1
bysort cty_rgn_no: egen n_month = total(month_one)

tab cty_rgn_no n_month

keep if n_month == 23

save "card_month_total_balanced.dta", replace

****************************************************
* 메인 DID 분석 1: 카드매출액
****************************************************

regress ln_amt did i.unit_id i.mdate

****************************************************
* 메인 DID 분석 2: 카드매출건수
****************************************************

regress ln_cnt did i.unit_id i.mdate



****************************************************
* 평행추세 확인
* 정책 시행 전 기간만 사용
****************************************************

gen t = mdate - ym(2023, 6) + 1
gen youth_t = youth * t

regress ln_amt youth t youth_t if mdate < ym(2024, 5)

regress ln_cnt youth t youth_t if mdate < ym(2024, 5)

****************************************************
* 청년층/일반층 카드매출 추세 그래프
****************************************************

use "`out'/card_month_total_balanced.dta", clear

collapse (mean) ln_amt ln_cnt, by(mdate youth)

* 카드 매출액
twoway ///
(line ln_amt mdate if youth == 1) ///
(line ln_amt mdate if youth == 0), ///
legend(label(1 "청년층") label(2 "일반층")) ///
xline(772) ///
title("The 경기패스 시행 전후 청년층과 일반층 카드매출 추세") ///
ytitle("로그 카드매출액") ///
xtitle("월")

* 결제건수
twoway ///
(line ln_cnt mdate if youth == 1) ///
(line ln_cnt mdate if youth == 0), ///
legend(label(1 "청년층") label(2 "일반층")) ///
xline(772) ///
title("The 경기패스 시행 전후 청년층과 일반층 결제건수 추세") ///
ytitle("로그 결제건수") ///
xtitle("월")