****************************************************
* CPI 총지수 데이터 만들기
****************************************************

clear all
set more off

cd "C:/Users/LG/Desktop/지민/수업자료/응용계량경제학/팀플/카드소비 데이터/분석용"

****************************************************
* CPI 원본 파일 불러오기
* CPI 파일이 분석용 폴더에 없다면 경로를 수정할 것
****************************************************

import delimited using "지출목적별_소비자물가지수_경기도_2022_2025.csv", ///
    clear varnames(nonames) encoding("cp949") stringcols(_all)

****************************************************
* 첫 행은 변수명 행이므로 제거
****************************************************

drop in 1

****************************************************
* 총지수 행만 남김
****************************************************

keep if v2 == "0 총지수"

****************************************************
* 월별 CPI 변수 이름 정리
* v3 = 2022.01, ..., v50 = 2025.12
****************************************************

local i = 3

forvalues y = 2022/2025 {
    forvalues m = 1/12 {
        local mm : display %02.0f `m'
        rename v`i' cpi`y'`mm'
        local i = `i' + 1
    }
}

****************************************************
* long 형태로 변환
****************************************************

gen id = 1

reshape long cpi, i(id) j(std_ym)

destring cpi, replace

gen year = floor(std_ym / 100)
gen month = mod(std_ym, 100)

gen mdate = ym(year, month)
format mdate %tm

keep mdate cpi

save "cpi_total.dta", replace

list in 1/10



****************************************************
* 전체 소비: 실질 카드매출액 DID
****************************************************

clear all
set more off

cd "C:/Users/LG/Desktop/지민/수업자료/응용계량경제학/팀플/카드소비 데이터/분석용"

use "card_month_total_balanced.dta", clear

merge m:1 mdate using "cpi_total.dta"

tab _merge
keep if _merge == 3
drop _merge

****************************************************
* 실질 카드매출액 생성
* CPI 기준이 2020=100이므로 /cpi*100
****************************************************

gen real_amt = amt / cpi * 100
gen ln_real_amt = ln(real_amt + 1)

****************************************************
* 비교용 명목 로그 매출도 확인
****************************************************

regress ln_amt did i.unit_id i.mdate

****************************************************
* CPI 조정 실질 로그 매출 DID
****************************************************

regress ln_real_amt did i.unit_id i.mdate



****************************************************
* 선택소비 묶음: 실질 카드매출액 DID
****************************************************

clear all
set more off

cd "C:/Users/LG/Desktop/지민/수업자료/응용계량경제학/팀플/카드소비 데이터/분석용"

use "card_month_sector_code.dta", clear

gen selective = 0
replace selective = 1 if sector == "음식"
replace selective = 1 if sector == "여가오락"
replace selective = 1 if sector == "공연전시"
replace selective = 1 if sector == "소매유통"

keep if selective == 1

collapse (sum) amt cnt, by(cty_rgn_no mdate youth post did)

merge m:1 mdate using "cpi_total.dta"

tab _merge
keep if _merge == 3
drop _merge

gen real_amt = amt / cpi * 100
gen ln_real_amt = ln(real_amt + 1)

egen unit_id = group(cty_rgn_no youth)

****************************************************
* 명목 선택소비 매출 DID
****************************************************

gen ln_amt = ln(amt + 1)
regress ln_amt did i.unit_id i.mdate

****************************************************
* 실질 선택소비 매출 DID
****************************************************

regress ln_real_amt did i.unit_id i.mdate