const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  const page = await context.newPage();

  try {
    console.log('=== 초기 크롤링 페이지 테스트 시작 ===\n');
    
    // 1. 페이지 열기
    console.log('1. http://localhost:7500/admin/initial_crawling 페이지 열기...');
    await page.goto('http://localhost:7500/admin/initial_crawling');
    await page.waitForLoadState('networkidle');
    console.log('✅ 페이지 로드 완료\n');

    // 2. 현재 크롤링 진행 상태 확인
    console.log('2. 현재 크롤링이 진행중인지 확인...');
    
    // 진행중 상태를 나타내는 여러 지표 확인
    const progressIndicators = {
      // 진행률 표시
      progressBar: await page.locator('.progress-bar, [role="progressbar"]').first().isVisible().catch(() => false),
      // 진행중 텍스트
      inProgressText: await page.locator('text=/진행중|진행 중|실행중|실행 중|In Progress/i').first().isVisible().catch(() => false),
      // 상태 뱃지
      statusBadge: await page.locator('.badge:has-text("진행중"), .badge:has-text("실행중")').first().isVisible().catch(() => false),
      // 스피너나 로딩 인디케이터
      loadingIndicator: await page.locator('.spinner, .loading, .animate-spin').first().isVisible().catch(() => false),
      // 중지 버튼의 존재 (진행중일 때만 나타남)
      stopButton: await page.locator('button:has-text("중지"), button:has-text("정지"), button:has-text("Stop")').first().isVisible().catch(() => false)
    };

    const isInProgress = Object.values(progressIndicators).some(indicator => indicator);
    
    console.log('진행 상태 확인 결과:');
    Object.entries(progressIndicators).forEach(([key, value]) => {
      console.log(`  - ${key}: ${value ? '✅' : '❌'}`);
    });
    console.log(`\n크롤링 상태: ${isInProgress ? '🔄 진행중' : '⏸️  대기중'}\n`);

    if (isInProgress) {
      // 3-1. 진행중인 경우
      console.log('3. 크롤링이 진행중입니다. 진행률 모니터링을 시작합니다...\n');
      
      // 초기 진행률 캡처
      let initialProgress = await captureProgress(page);
      console.log(`초기 진행률: ${initialProgress || '알 수 없음'}`);
      
      // 단계 정보 캡처
      let initialStage = await captureStageInfo(page);
      console.log(`현재 단계: ${initialStage || '알 수 없음'}\n`);
      
      // 스크린샷 캡처
      await page.screenshot({ path: 'screenshots/crawling_in_progress_initial.png', fullPage: true });
      console.log('📸 진행중 초기 상태 스크린샷 저장\n');
      
      // 10초 동안 진행률 모니터링
      console.log('10초 동안 진행률 변화 모니터링...');
      const startTime = Date.now();
      let progressUpdates = [];
      let stageChanges = [];
      
      while (Date.now() - startTime < 10000) {
        await page.waitForTimeout(1000); // 1초마다 확인
        
        const currentProgress = await captureProgress(page);
        const currentStage = await captureStageInfo(page);
        
        if (currentProgress && currentProgress !== initialProgress) {
          progressUpdates.push({
            time: Math.floor((Date.now() - startTime) / 1000),
            progress: currentProgress
          });
          console.log(`  [${Math.floor((Date.now() - startTime) / 1000)}초] 진행률 업데이트: ${currentProgress}`);
          initialProgress = currentProgress;
        }
        
        if (currentStage && currentStage !== initialStage) {
          stageChanges.push({
            time: Math.floor((Date.now() - startTime) / 1000),
            stage: currentStage
          });
          console.log(`  [${Math.floor((Date.now() - startTime) / 1000)}초] 단계 변경: ${currentStage}`);
          initialStage = currentStage;
        }
      }
      
      console.log('\n모니터링 결과:');
      console.log(`- 진행률 업데이트 횟수: ${progressUpdates.length}회`);
      console.log(`- 단계 변경 횟수: ${stageChanges.length}회`);
      
      // 최종 스크린샷
      await page.screenshot({ path: 'screenshots/crawling_in_progress_final.png', fullPage: true });
      console.log('\n📸 진행중 최종 상태 스크린샷 저장');
      
    } else {
      // 3-2. 진행중이 아닌 경우
      console.log('3. 크롤링이 진행중이 아닙니다. "초기 크롤링 시작" 버튼을 찾습니다...\n');
      
      // 시작 버튼 찾기
      const startButtonSelectors = [
        'button:has-text("초기 크롤링 시작")',
        'button:has-text("크롤링 시작")',
        'button:has-text("시작")',
        '[data-action*="startCrawling"]',
        'button[type="submit"]:not(:disabled)'
      ];
      
      let startButton = null;
      for (const selector of startButtonSelectors) {
        try {
          const button = await page.locator(selector).first();
          if (await button.isVisible()) {
            startButton = button;
            console.log(`✅ 시작 버튼 찾음: ${selector}`);
            break;
          }
        } catch (e) {
          // 다음 선택자 시도
        }
      }
      
      if (!startButton) {
        throw new Error('시작 버튼을 찾을 수 없습니다.');
      }
      
      // 시작 전 스크린샷
      await page.screenshot({ path: 'screenshots/before_start.png', fullPage: true });
      console.log('📸 시작 전 스크린샷 저장\n');
      
      // 버튼 클릭
      console.log('버튼 클릭...');
      await startButton.click();
      console.log('✅ 버튼 클릭 완료\n');
      
      // 10초 대기하며 변화 관찰
      console.log('10초 동안 진행률 변화 관찰...');
      const startTime = Date.now();
      let progressDetected = false;
      
      while (Date.now() - startTime < 10000) {
        await page.waitForTimeout(1000);
        
        const progress = await captureProgress(page);
        const stage = await captureStageInfo(page);
        
        if (progress || stage) {
          if (!progressDetected) {
            console.log('\n✅ 크롤링이 시작되었습니다!');
            progressDetected = true;
          }
          
          const elapsed = Math.floor((Date.now() - startTime) / 1000);
          if (progress) console.log(`  [${elapsed}초] 진행률: ${progress}`);
          if (stage) console.log(`  [${elapsed}초] 단계: ${stage}`);
        }
      }
      
      if (!progressDetected) {
        console.log('\n⚠️  10초 동안 진행률 변화가 감지되지 않았습니다.');
        
        // 에러 메시지 확인
        const errorMessage = await page.locator('.alert-danger, .error, [role="alert"]').first().textContent().catch(() => null);
        if (errorMessage) {
          console.log(`❌ 에러 메시지: ${errorMessage}`);
        }
      }
      
      // 최종 스크린샷
      await page.screenshot({ path: 'screenshots/after_start_final.png', fullPage: true });
      console.log('\n📸 시작 후 최종 스크린샷 저장');
    }
    
    console.log('\n=== 테스트 완료 ===');
    
  } catch (error) {
    console.error('\n❌ 테스트 중 오류 발생:', error.message);
    await page.screenshot({ path: 'screenshots/error_state.png', fullPage: true });
    console.log('📸 오류 상태 스크린샷 저장');
  } finally {
    console.log('\n브라우저를 닫으려면 아무 키나 누르세요...');
    await page.pause();
    await browser.close();
  }
})();

// 진행률 캡처 함수
async function captureProgress(page) {
  // 여러 가능한 진행률 표시 방법 확인
  const progressSelectors = [
    '.progress-bar',
    '[role="progressbar"]',
    '[data-progress]',
    '.progress-value',
    'text=/%/'
  ];
  
  for (const selector of progressSelectors) {
    try {
      const element = await page.locator(selector).first();
      if (await element.isVisible({ timeout: 500 })) {
        // aria-valuenow 속성 확인
        const ariaValue = await element.getAttribute('aria-valuenow').catch(() => null);
        if (ariaValue) return `${ariaValue}%`;
        
        // style width 확인
        const style = await element.getAttribute('style').catch(() => null);
        if (style) {
          const widthMatch = style.match(/width:\s*(\d+)/);
          if (widthMatch) return `${widthMatch[1]}%`;
        }
        
        // 텍스트 내용 확인
        const text = await element.textContent();
        const percentMatch = text.match(/(\d+)%/);
        if (percentMatch) return percentMatch[0];
      }
    } catch (e) {
      // 다음 선택자 시도
    }
  }
  
  return null;
}

// 단계 정보 캡처 함수
async function captureStageInfo(page) {
  // 먼저 현재 진행 중인 단계 찾기 (파란색 테두리)
  try {
    const runningStep = await page.locator('.border-blue-500').first();
    if (await runningStep.isVisible({ timeout: 500 })) {
      // 단계 이름 가져오기
      const stepName = await runningStep.locator('h3').textContent();
      // 상태 텍스트 가져오기 (진행 중, 내부X단계 등)
      const statusText = await runningStep.locator('p').textContent();
      
      if (stepName || statusText) {
        return `${stepName} - ${statusText}`.trim();
      }
    }
  } catch (e) {
    // 다른 방법 시도
  }
  
  // 대체 방법들
  const stageSelectors = [
    '.stage-info',
    '.current-stage',
    '.step-indicator',
    '[data-stage]',
    '.status-text',
    'text=/단계|Step|Stage/i'
  ];
  
  for (const selector of stageSelectors) {
    try {
      const element = await page.locator(selector).first();
      if (await element.isVisible({ timeout: 500 })) {
        const text = await element.textContent();
        if (text && text.trim()) return text.trim();
      }
    } catch (e) {
      // 다음 선택자 시도
    }
  }
  
  return null;
}