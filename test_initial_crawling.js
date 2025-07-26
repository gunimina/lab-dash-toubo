const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  const page = await context.newPage();

  try {
    console.log('1. http://localhost:7500/admin/initial_crawling 접속 중...');
    await page.goto('http://localhost:7500/admin/initial_crawling');
    
    // 페이지 로드 대기
    await page.waitForLoadState('networkidle');
    console.log('✅ 페이지 접속 완료');
    
    // 초기 화면 스크린샷
    await page.screenshot({ path: 'screenshots/01_initial_page.png', fullPage: true });
    console.log('📸 초기 화면 스크린샷 저장: screenshots/01_initial_page.png');

    console.log('\n2. "초기 크롤링 시작" 버튼 찾기...');
    // 버튼 찾기 - 여러 가능한 선택자 시도
    const buttonSelectors = [
      'button:has-text("초기 크롤링 시작")',
      'text="초기 크롤링 시작"',
      'button[type="submit"]:has-text("초기 크롤링 시작")',
      '[data-action*="click->crawling_monitor#startCrawling"]'
    ];
    
    let button = null;
    for (const selector of buttonSelectors) {
      try {
        button = await page.locator(selector).first();
        if (await button.isVisible()) {
          console.log(`✅ 버튼 찾음: ${selector}`);
          break;
        }
      } catch (e) {
        // 다음 선택자 시도
      }
    }
    
    if (!button || !(await button.isVisible())) {
      throw new Error('초기 크롤링 시작 버튼을 찾을 수 없습니다.');
    }

    console.log('\n3. 버튼 클릭 중...');
    await button.click();
    console.log('✅ 버튼 클릭 완료');
    
    // 클릭 직후 스크린샷
    await page.screenshot({ path: 'screenshots/02_after_click.png', fullPage: true });
    console.log('📸 클릭 후 스크린샷 저장: screenshots/02_after_click.png');

    console.log('\n4. 화면 변화 확인 중...');
    // 여러 가능한 변화 확인
    const changeIndicators = [
      // 진행 상태 표시
      '[data-crawling-status-target="progress"]',
      '.progress-bar',
      
      // 로딩 표시
      '.loading',
      '.spinner',
      
      // 상태 카드 업데이트
      '[data-crawling-status-target="statusCard"]',
      '.status-card',
      
      // 메시지
      '.alert',
      '[role="alert"]',
      '.flash',
      '.notice',
      '.error'
    ];
    
    let changeDetected = false;
    for (const selector of changeIndicators) {
      try {
        const element = await page.locator(selector).first();
        if (await element.isVisible({ timeout: 5000 })) {
          console.log(`✅ 변화 감지: ${selector}`);
          changeDetected = true;
          break;
        }
      } catch (e) {
        // 다음 선택자 시도
      }
    }

    if (!changeDetected) {
      console.log('⚠️  명시적인 UI 변화를 감지하지 못했습니다. 네트워크 요청 확인 중...');
    }

    // 5초 대기 후 상태 확인
    await page.waitForTimeout(5000);
    
    console.log('\n5. 에러 메시지나 성공 메시지 확인 중...');
    
    // 에러 메시지 확인
    const errorSelectors = [
      '.alert-danger',
      '.error',
      '[data-alert-type="error"]',
      'text=/error|실패|오류/i'
    ];
    
    let errorFound = false;
    for (const selector of errorSelectors) {
      try {
        const error = await page.locator(selector).first();
        if (await error.isVisible({ timeout: 1000 })) {
          const errorText = await error.textContent();
          console.log(`❌ 에러 메시지 발견: ${errorText}`);
          errorFound = true;
        }
      } catch (e) {
        // 에러 없음
      }
    }
    
    // 성공 메시지 확인
    const successSelectors = [
      '.alert-success',
      '.success',
      '[data-alert-type="success"]',
      'text=/성공|시작|진행/i'
    ];
    
    let successFound = false;
    for (const selector of successSelectors) {
      try {
        const success = await page.locator(selector).first();
        if (await success.isVisible({ timeout: 1000 })) {
          const successText = await success.textContent();
          console.log(`✅ 성공 메시지 발견: ${successText}`);
          successFound = true;
        }
      } catch (e) {
        // 성공 메시지 없음
      }
    }
    
    if (!errorFound && !successFound) {
      console.log('ℹ️  명시적인 에러나 성공 메시지를 찾지 못했습니다.');
    }

    // 최종 스크린샷
    await page.screenshot({ path: 'screenshots/03_final_state.png', fullPage: true });
    console.log('\n📸 최종 상태 스크린샷 저장: screenshots/03_final_state.png');

    // 콘솔 로그 확인
    console.log('\n📋 브라우저 콘솔 로그:');
    page.on('console', msg => console.log(`  ${msg.type()}: ${msg.text()}`));

    // 10초 추가 대기하여 진행 상황 관찰
    console.log('\n⏳ 10초간 추가 관찰 중...');
    await page.waitForTimeout(10000);
    
    // 최종 진행 상황 스크린샷
    await page.screenshot({ path: 'screenshots/04_progress_update.png', fullPage: true });
    console.log('📸 진행 상황 스크린샷 저장: screenshots/04_progress_update.png');

  } catch (error) {
    console.error('\n❌ 테스트 중 오류 발생:', error);
    await page.screenshot({ path: 'screenshots/error_state.png', fullPage: true });
    console.log('📸 오류 상태 스크린샷 저장: screenshots/error_state.png');
  } finally {
    console.log('\n테스트 완료. 브라우저를 닫으려면 아무 키나 누르세요...');
    await page.pause();
    await browser.close();
  }
})();