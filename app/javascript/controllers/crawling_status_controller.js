import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    sessionId: Number,
    pollInterval: { type: Number, default: 10000 } // 기본 10초
  }
  
  connect() {
    console.log("Crawling status controller connected", {
      sessionId: this.sessionIdValue,
      pollInterval: this.pollIntervalValue
    })
    
    // Webhook이 있으므로 Ajax 폴링 비활성화
    // 실시간 업데이트는 Turbo Streams broadcast로 처리
    console.log("Ajax polling disabled - using Turbo Streams broadcast")
    
    // if (this.sessionIdValue) {
    //   this.startPolling()
    // }
    
    // 크롤링 중지 이벤트 리스너
    this.handleCrawlingStopped = () => {
      console.log('Crawling stopped event received')
      this.sessionIdValue = null
      this.stopPolling()
    }
    document.addEventListener('crawling:stopped', this.handleCrawlingStopped)
  }
  
  disconnect() {
    this.stopPolling()
    if (this.handleCrawlingStopped) {
      document.removeEventListener('crawling:stopped', this.handleCrawlingStopped)
    }
  }
  
  startPolling() {
    // 즉시 한 번 실행
    this.fetchStatus()
    
    // 동적 폴링 간격 설정
    this.schedulePoll()
  }
  
  schedulePoll() {
    const currentStep = this.getCurrentStep()
    const currentSubStep = this.getCurrentSubStep()
    
    // 단계별 폴링 간격 설정
    let interval = 30000 // 기본 30초
    
    if (currentStep === 1) {
      // Step 1의 내부 단계별 간격
      switch(currentSubStep) {
        case 1: interval = 10000; break;  // 카테고리: 10초
        case 2: interval = 60000; break;  // 부모상품: 1분
        case 3: interval = 30000; break;  // 자식상품: 30초
        default: interval = 30000;
      }
    } else if (currentStep === 2) {
      interval = 60000;  // AI 처리: 1분
    } else if (currentStep === 3) {
      interval = 30000;  // 카탈로그: 30초
    } else if (currentStep === 4) {
      interval = 30000;  // DB: 30초
    }
    
    console.log(`Next poll in ${interval/1000} seconds for Step ${currentStep}`)
    
    this.pollTimer = setTimeout(() => {
      this.fetchStatus()
      this.schedulePoll() // 다음 폴링 예약
    }, interval)
  }
  
  getCurrentStep() {
    const stepIndicator = document.querySelector('[id^="step-"][class*="border-blue-500"]')
    if (stepIndicator) {
      const match = stepIndicator.id.match(/step-(\d+)/)
      return match ? parseInt(match[1]) : 0
    }
    return 0
  }
  
  getCurrentSubStep() {
    const subStepText = document.querySelector('[id^="step-1-status"] .block')
    if (subStepText && subStepText.textContent.includes('내부')) {
      const match = subStepText.textContent.match(/내부 (\d+)단계/)
      return match ? parseInt(match[1]) : null
    }
    return null
  }
  
  stopPolling() {
    if (this.pollTimer) {
      clearTimeout(this.pollTimer)  // setTimeout이므로 clearTimeout 사용
      this.pollTimer = null
    }
  }
  
  async fetchStatus() {
    if (!this.sessionIdValue) {
      console.log('No sessionId, skipping fetch')
      return
    }
    
    try {
      console.log(`Fetching status for session ${this.sessionIdValue}`)
      const response = await fetch(`/admin/initial_crawling/${this.sessionIdValue}/status`, {
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })
      
      if (!response.ok) {
        console.error('Failed to fetch status:', response.status)
        return
      }
      
      const text = await response.text()
      console.log('Received response:', text.substring(0, 100) + '...')
      
      // Turbo가 자동으로 처리하도록 함
      Turbo.renderStreamMessage(text)
      
      // 크롤링 완료 상태 확인
      setTimeout(() => {
        const controlPanel = document.querySelector('[data-crawling-status]')
        if (controlPanel) {
          const status = controlPanel.dataset.crawlingStatus
          console.log('Current status:', status)
          if (['completed', 'stopped', 'failed'].includes(status)) {
            this.stopPolling()
            console.log('Crawling finished, stopping polling')
            
            // completed 상태면 세션 정보 초기화
            if (status === 'completed') {
              this.sessionIdValue = null
              console.log('Crawling completed, session cleared')
            }
          }
        }
      }, 100)
    } catch (error) {
      console.error('Error fetching status:', error)
    }
  }
}