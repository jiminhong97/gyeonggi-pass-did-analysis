****************************************************
* 업종별 DID 분석용 데이터 다시 만들기
* 업종명 깨짐 방지를 위해 card_tpbuz_cd 기준 사용
****************************************************

clear all
set more off

****************************************************
* 1. 경로 설정
****************************************************

global raw "C:/Users/LG/Desktop/지민/수업자료/응용계량경제학/팀플/카드소비 데이터"
global out "C:/Users/LG/Desktop/지민/수업자료/응용계량경제학/팀플/카드소비 데이터/분석용"

capture mkdir "$out"

****************************************************
* 2. 원본 CSV 목록 가져오기
****************************************************

local files : dir "$raw" files "*.csv"
local nfiles : word count `files'

display "CSV 파일 개수 = `nfiles'"

if `nfiles' == 0 {
    display "CSV 파일을 찾지 못함. raw 경로를 확인할 것."
    exit
}

****************************************************
* 3. 파일 하나씩 처리
****************************************************

local first = 1
local done = 0

foreach f of local files {

    display "========================================"
    display "처리 중인 파일: `f'"
    display "========================================"

    import delimited using "$raw/`f'", clear varnames(1) encoding("utf-8")

    ************************************************
    * 필요한 변수 확인
    ************************************************

    foreach v in ta_ymd cty_rgn_no card_tpbuz_cd age amt cnt {
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

    keep ta_ymd cty_rgn_no card_tpbuz_cd age amt cnt

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
    * 업종코드가 문자열인지 확인
    ************************************************

    capture confirm string variable card_tpbuz_cd
    if _rc {
        tostring card_tpbuz_cd, replace
    }

    ************************************************
    * 분석 기간 설정
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
    * 업종대분류 생성
    * card_tpbuz_cd의 첫 글자를 기준으로 분류
    ************************************************

    gen sector_code = substr(card_tpbuz_cd, 1, 1)
    replace sector_code = upper(sector_code)

    gen sector = ""

    replace sector = "소매유통"     if sector_code == "D"
    replace sector = "생활서비스"   if sector_code == "F"
    replace sector = "여가오락"     if sector_code == "O"
    replace sector = "음식"         if sector_code == "Q"
    replace sector = "학문교육"     if sector_code == "R"
    replace sector = "의료건강"     if sector_code == "S"
    replace sector = "공연전시"     if sector_code == "T"
    replace sector = "미디어통신"   if sector_code == "U"
    replace sector = "공공기업단체" if sector_code == "Y"

    keep if sector != ""

    ************************************************
    * 월별 분석 단위로 축소
    * 시군구 × 월 × 청년여부 × 업종
    ************************************************

    collapse (sum) amt cnt, by(cty_rgn_no mdate youth post did sector)

    ************************************************
    * 누적 저장
    ************************************************

    if `first' == 1 {
        save "$out/card_month_sector_code.dta", replace
        local first = 0
    }
    else {
        append using "$out/card_month_sector_code.dta"
        save "$out/card_month_sector_code.dta", replace
    }

    local done = `done' + 1
    display "완료된 파일 수 = `done'"
}

****************************************************
* 4. 업종별 데이터 확인
****************************************************

use "$out/card_month_sector_code.dta", clear

describe
count
tab mdate
tab cty_rgn_no
tab youth
tab sector

save "$out/card_month_sector_code.dta", replace



****************************************************
* 업종별 DID 분석: 매출액 + 결제건수
****************************************************

clear all
set more off

cd "C:/Users/LG/Desktop/지민/수업자료/응용계량경제학/팀플/카드소비 데이터/분석용"

use "card_month_sector_code.dta", clear

****************************************************
* 로그 종속변수 생성
****************************************************

gen ln_amt = ln(amt + 1)
gen ln_cnt = ln(cnt + 1)

****************************************************
* 업종별 DID 분석
****************************************************

levelsof sector, local(sectors)

foreach s of local sectors {

    display " "
    display "========================================"
    display "업종: `s'"
    display "종속변수: 로그 카드매출액"
    display "========================================"

    preserve
        keep if sector == "`s'"
        egen unit_id = group(cty_rgn_no youth)
        regress ln_amt did i.unit_id i.mdate
    restore

    display " "
    display "========================================"
    display "업종: `s'"
    display "종속변수: 로그 결제건수"
    display "========================================"

    preserve
        keep if sector == "`s'"
        egen unit_id = group(cty_rgn_no youth)
        regress ln_cnt did i.unit_id i.mdate
    restore
}



****************************************************
* 업종별 DID 결과표 만들기
****************************************************

clear all
set more off

cd "C:/Users/LG/Desktop/지민/수업자료/응용계량경제학/팀플/카드소비 데이터/분석용"

use "card_month_sector_code.dta", clear

gen ln_amt = ln(amt + 1)
gen ln_cnt = ln(cnt + 1)

tempfile result
postfile handle str20 sector str10 outcome double coef se t p using "`result'", replace

levelsof sector, local(sectors)

foreach s of local sectors {

    preserve
        keep if sector == "`s'"
        egen unit_id = group(cty_rgn_no youth)

        regress ln_amt did i.unit_id i.mdate

        local b = _b[did]
        local se = _se[did]
        local t = _b[did] / _se[did]
        local p = 2 * ttail(e(df_r), abs(`t'))

        post handle ("`s'") ("ln_amt") (`b') (`se') (`t') (`p')
    restore

    preserve
        keep if sector == "`s'"
        egen unit_id = group(cty_rgn_no youth)

        regress ln_cnt did i.unit_id i.mdate

        local b = _b[did]
        local se = _se[did]
        local t = _b[did] / _se[did]
        local p = 2 * ttail(e(df_r), abs(`t'))

        post handle ("`s'") ("ln_cnt") (`b') (`se') (`t') (`p')
    restore
}

postclose handle

use "`result'", clear

gen pct_effect = (exp(coef) - 1) * 100

list sector outcome coef se t p pct_effect, sepby(sector)

save "sector_did_result.dta", replace
export delimited using "sector_did_result.csv", replace



****************************************************
* 강건성 분석 1: 정책 시행월 제외
****************************************************

cd "C:/Users/LG/Desktop/지민/수업자료/응용계량경제학/팀플/카드소비 데이터/분석용"

use "card_month_total_balanced.dta", clear

drop if mdate == ym(2024, 5)

regress ln_amt did i.unit_id i.mdate
regress ln_cnt did i.unit_id i.mdate

****************************************************
* 업종별 강건성 분석: 정책 시행월 제외
****************************************************

use "card_month_sector_code.dta", clear

drop if mdate == ym(2024, 5)

gen ln_amt = ln(amt + 1)
gen ln_cnt = ln(cnt + 1)

tempfile result_no_may
postfile handle str20 sector str10 outcome double coef se t p pct_effect using "`result_no_may'", replace

levelsof sector, local(sectors)

foreach s of local sectors {

    preserve
        keep if sector == "`s'"
        egen unit_id = group(cty_rgn_no youth)

        regress ln_amt did i.unit_id i.mdate

        local b = _b[did]
        local se = _se[did]
        local t = _b[did] / _se[did]
        local p = 2 * ttail(e(df_r), abs(`t'))
        local pct = (exp(`b') - 1) * 100

        post handle ("`s'") ("ln_amt") (`b') (`se') (`t') (`p') (`pct')
    restore

    preserve
        keep if sector == "`s'"
        egen unit_id = group(cty_rgn_no youth)

        regress ln_cnt did i.unit_id i.mdate

        local b = _b[did]
        local se = _se[did]
        local t = _b[did] / _se[did]
        local p = 2 * ttail(e(df_r), abs(`t'))
        local pct = (exp(`b') - 1) * 100

        post handle ("`s'") ("ln_cnt") (`b') (`se') (`t') (`p') (`pct')
    restore
}

postclose handle

use "`result_no_may'", clear
list sector outcome coef p pct_effect, sepby(sector)

save "sector_did_result_no_may.dta", replace
export delimited using "sector_did_result_no_may.csv", replace

****************************************************
* 선택소비 업종 묶음 DID
****************************************************

cd "C:/Users/LG/Desktop/지민/수업자료/응용계량경제학/팀플/카드소비 데이터/분석용"

use "card_month_sector_code.dta", clear

gen selective = 0
replace selective = 1 if sector == "음식"
replace selective = 1 if sector == "여가오락"
replace selective = 1 if sector == "공연전시"
replace selective = 1 if sector == "소매유통"

keep if selective == 1

collapse (sum) amt cnt, by(cty_rgn_no mdate youth post did)

gen ln_amt = ln(amt + 1)
gen ln_cnt = ln(cnt + 1)

egen unit_id = group(cty_rgn_no youth)

regress ln_amt did i.unit_id i.mdate
regress ln_cnt did i.unit_id i.mdate

****************************************************
* 정책 전후 평균 비교표: 전체 소비
****************************************************

cd "C:/Users/LG/Desktop/지민/수업자료/응용계량경제학/팀플/카드소비 데이터/분석용"

use "card_month_total_balanced.dta", clear

tabstat ln_amt ln_cnt, s(n mean sd) by(youth)

sort youth post
by youth post: summarize ln_amt
by youth post: summarize ln_cnt

****************************************************
* 정책 전후 평균 비교표: 업종별
****************************************************

use "card_month_sector_code.dta", clear

gen ln_amt = ln(amt + 1)
gen ln_cnt = ln(cnt + 1)

sort sector youth post

by sector youth post: summarize ln_amt
by sector youth post: summarize ln_cnt

****************************************************
* 선택소비 업종 묶음 추세 그래프
****************************************************

cd "C:/Users/LG/Desktop/지민/수업자료/응용계량경제학/팀플/카드소비 데이터/분석용"

use "card_month_sector_code.dta", clear

gen selective = 0
replace selective = 1 if sector == "음식"
replace selective = 1 if sector == "여가오락"
replace selective = 1 if sector == "공연전시"
replace selective = 1 if sector == "소매유통"

keep if selective == 1

collapse (sum) amt cnt, by(cty_rgn_no mdate youth post did)

gen ln_amt = ln(amt + 1)
gen ln_cnt = ln(cnt + 1)

collapse (mean) ln_amt ln_cnt, by(mdate youth)

twoway ///
(line ln_amt mdate if youth == 1) ///
(line ln_amt mdate if youth == 0), ///
legend(label(1 "청년층") label(2 "일반층")) ///
xline(772) ///
title("The 경기패스 시행 전후 선택소비 카드매출 추세") ///
ytitle("로그 카드매출액") ///
xtitle("월")