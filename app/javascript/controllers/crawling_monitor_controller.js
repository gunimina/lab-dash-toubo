import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    sessionId: String,
    statusUrl: String,
    polling: Boolean 
  }
  
  connect() {
    console.log("Crawling monitor connected")
    console.log("Controller element:", this.element)
    console.log("Found buttons with data-action:", this.element.querySelectorAll('[data-action*="crawling-monitor"]'))
    
    // 디버깅: 모든 버튼의 data-action 확인
    const allButtons = this.element.querySelectorAll('button[data-action]')
    allButtons.forEach(btn => {
      console.log("Button:", btn.textContent.trim(), "Action:", btn.dataset.action)
    })
    
    this.pollingValue = false
    
    // Turbo Streams 이벤트 리스닝
    this.handleBeforeStreamRender = (event) => {
      const stream = event.detail.newStream
      console.log('Stream render starting:', {
        action: stream.action,
        target: stream.target
      })
      
      // control-panel 업데이트 전 상태 저장
      if (stream.target === 'control-panel') {
        this.previousControlPanel = document.getElementById('control-panel')?.innerHTML
        this.previousStatus = document.querySelector('[data-crawling-status]')?.dataset.crawlingStatus
      }
    }
    
    this.handleAfterStreamRender = (event) => {
      console.log('Stream render completed')
      
      // Stimulus controller 재연결 확인
      setTimeout(() => {
        const buttons = document.querySelectorAll('[data-action*="crawling-monitor"]')
        console.log('After render - Found buttons:', buttons.length)
        buttons.forEach(btn => {
          console.log('Button after render:', btn.textContent.trim(), btn.dataset.action)
        })
      }, 100)
      
      // stop 명령을 기다리고 있었다면 특별 처리
      if (this.expectingStopUpdate) {
        this.verifyStopUpdate()
        this.expectingStopUpdate = false
        return
      }
      
      // 일반적인 렌더링 성공 확인
      setTimeout(() => {
        const currentPanel = document.getElementById('control-panel')
        if (currentPanel && this.previousControlPanel === currentPanel.innerHTML) {
          console.warn('Control panel not updated, forcing refresh')
          Turbo.visit(window.location.href, { action: 'replace' })
        }
      }, 100)
    }
    
    document.addEventListener('turbo:before-stream-render', this.handleBeforeStreamRender)
    // turbo:render가 아니라 turbo:after-stream-render 이벤트 사용
    document.addEventListener('turbo:after-stream-render', this.handleAfterStreamRender)
    
    // 추가 Turbo 이벤트 디버깅
    document.addEventListener('turbo:submit-start', (e) => console.log('turbo:submit-start', e))
    document.addEventListener('turbo:submit-end', (e) => console.log('turbo:submit-end', e))
    document.addEventListener('turbo:before-fetch-request', (e) => console.log('turbo:before-fetch-request', e))
    document.addEventListener('turbo:before-fetch-response', (e) => console.log('turbo:before-fetch-response', e))
    
    // 현재 상태 확인
    const statusElement = this.element.querySelector('[data-crawling-status]')
    if (statusElement) {
      const status = statusElement.dataset.crawlingStatus
      if (status === 'running' || status === 'paused') {
        this.startPolling()
      }
    }
    
    // ESC 키로 모달 닫기
    this.handleEscape = (event) => {
      if (event.key === 'Escape') {
        const modal = document.getElementById('reset-modal')
        if (modal && !modal.classList.contains('hidden')) {
          this.closeResetModal(event)
        }
      }
    }
    document.addEventListener('keydown', this.handleEscape)
    
    // 크롤링 시작 이벤트 리스너
    this.handleCrawlingStarted = (event) => {
      console.log('Crawling started event received:', event.detail)
      this.sessionIdValue = event.detail.sessionId
      this.statusUrlValue = event.detail.statusUrl
      // 폴링은 비활성화 (Turbo Streams broadcast 사용)
      // this.startPolling()
    }
    document.addEventListener('crawling:started', this.handleCrawlingStarted)
  }
  
  disconnect() {
    this.stopPolling()
    // 이벤트 리스너 제거
    if (this.handleEscape) {
      document.removeEventListener('keydown', this.handleEscape)
    }
    if (this.handleCrawlingStarted) {
      document.removeEventListener('crawling:started', this.handleCrawlingStarted)
    }
    if (this.handleBeforeStreamRender) {
      document.removeEventListener('turbo:before-stream-render', this.handleBeforeStreamRender)
    }
    if (this.handleAfterStreamRender) {
      document.removeEventListener('turbo:after-stream-render', this.handleAfterStreamRender)
    }
  }
  
  async start(event) {
    event.preventDefault()
    console.log("Starting crawling...")
    console.log("CSRF Token:", this.csrfToken)
    console.log("URL:", '/admin/initial_crawling/start')
    
    try {
      const response = await fetch('/admin/initial_crawling/start', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.csrfToken,
          'Accept': 'text/vnd.turbo-stream.html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      console.log('Response status:', response.status)
      console.log('Response headers:', response.headers)
      
      if (response.ok) {
        const html = await response.text()
        console.log('Response HTML:', html)
        
        // Turbo Stream 메시지 처리
        if (html.includes('turbo-stream')) {
          try {
            Turbo.renderStreamMessage(html)
            console.log('Turbo Stream processed')
            
            // UI 업데이트 확인
            setTimeout(() => {
              const statusEl = document.querySelector('[data-crawling-status]')
              if (statusEl && statusEl.dataset.crawlingStatus !== 'running') {
                console.warn('UI not updated after start, forcing reload...')
                window.location.reload()
              }
            }, 500)
          } catch (error) {
            console.error('Error processing Turbo Stream:', error)
            window.location.reload()
          }
        } else {
          console.error('Response is not a Turbo Stream:', html)
          window.location.reload()
        }
        
        console.log('Crawling started successfully')
        // 세션 정보는 crawling:started 이벤트로 받음
      } else {
        console.error('Failed to start crawling:', response.status)
        const errorText = await response.text()
        console.error('Error response:', errorText)
      }
    } catch (error) {
      console.error('Error starting crawling:', error)
      alert('크롤링 시작 중 오류가 발생했습니다: ' + error.message)
    }
  }
  
  async pause(event) {
    event.preventDefault()
    console.log("Pausing crawler...")
    
    try {
      const response = await fetch('/admin/initial_crawling/pause', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.csrfToken,
          'Accept': 'text/vnd.turbo-stream.html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (response.ok) {
        const html = await response.text()
        try {
          Turbo.renderStreamMessage(html)
          console.log('Turbo Stream processed for pause')
          
          setTimeout(() => {
            const statusEl = document.querySelector('[data-crawling-status]')
            if (statusEl && statusEl.dataset.crawlingStatus !== 'paused') {
              console.warn('UI not updated after pause, forcing reload...')
              window.location.reload()
            }
          }, 500)
        } catch (error) {
          console.error('Error processing Turbo Stream:', error)
          window.location.reload()
        }
      } else {
        console.error('Failed to pause crawler:', response.status)
      }
    } catch (error) {
      console.error('Error pausing crawler:', error)
    }
  }
  
  async resume(event) {
    event.preventDefault()
    console.log("Resuming crawler...")
    
    try {
      const response = await fetch('/admin/initial_crawling/resume', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.csrfToken,
          'Accept': 'text/vnd.turbo-stream.html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (response.ok) {
        const html = await response.text()
        try {
          Turbo.renderStreamMessage(html)
          console.log('Turbo Stream processed for resume')
          
          setTimeout(() => {
            const statusEl = document.querySelector('[data-crawling-status]')
            if (statusEl && statusEl.dataset.crawlingStatus !== 'running') {
              console.warn('UI not updated after resume, forcing reload...')
              window.location.reload()
            }
          }, 500)
        } catch (error) {
          console.error('Error processing Turbo Stream:', error)
          window.location.reload()
        }
      } else {
        console.error('Failed to resume crawler:', response.status)
      }
    } catch (error) {
      console.error('Error resuming crawler:', error)
    }
  }
  
  async stop(event) {
    event.preventDefault()
    console.log("Stopping crawler...")
    console.log("CSRF Token:", this.csrfToken)
    console.log("Stop URL:", '/admin/initial_crawling/stop')
    
    // Turbo 이벤트로 처리 상태 추적
    this.expectingStopUpdate = true
    
    try {
      console.log("Sending stop request...")
      const response = await fetch('/admin/initial_crawling/stop', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.csrfToken,
          'Accept': 'text/vnd.turbo-stream.html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      console.log("Stop response received:", response.status, response.statusText)
      
      if (response.ok) {
        const html = await response.text()
        console.log("Stop response HTML length:", html.length)
        console.log("First 200 chars:", html.substring(0, 200))
        
        if (html.includes('turbo-stream')) {
          // Turbo가 자동으로 처리하도록 함
          console.log("Rendering Turbo Stream...")
          Turbo.renderStreamMessage(html)
          this.stopPolling()
          
          // Turbo 이벤트가 처리할 것이므로 여기서는 추가 작업 불필요
          console.log('Stop request sent, waiting for Turbo events...')
          
          // Turbo morph 완료를 기다림
        } else {
          console.error('Response is not a Turbo Stream')
          window.location.reload()
        }
      } else {
        console.error('Failed to stop crawler:', response.status, response.statusText)
        const errorText = await response.text()
        console.error('Error response:', errorText)
        this.expectingStopUpdate = false
      }
    } catch (error) {
      console.error('Error stopping crawler:', error)
      console.error('Error details:', error.message, error.stack)
      this.expectingStopUpdate = false
    }
  }
  
  async reset(event) {
    event.preventDefault()
    console.log("Opening reset modal...")
    
    // 모달 표시
    const modal = document.getElementById('reset-modal')
    if (modal) {
      modal.classList.remove('hidden')
    }
  }
  
  closeResetModal(event) {
    event.preventDefault()
    console.log("Closing reset modal...")
    
    const modal = document.getElementById('reset-modal')
    if (modal) {
      modal.classList.add('hidden')
    }
  }
  
  async confirmReset(event) {
    event.preventDefault()
    console.log("Confirming reset...")
    
    // 모달 닫기
    const modal = document.getElementById('reset-modal')
    if (modal) {
      modal.classList.add('hidden')
    }
    
    // 초기화 실행
    try {
      const response = await fetch('/admin/initial_crawling/reset', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.csrfToken,
          'Accept': 'text/vnd.turbo-stream.html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (response.ok) {
        const html = await response.text()
        try {
          Turbo.renderStreamMessage(html)
          console.log('Turbo Stream processed for reset')
          
          setTimeout(() => {
            window.location.reload()
          }, 500)
        } catch (error) {
          console.error('Error processing Turbo Stream:', error)
          window.location.reload()
        }
      } else {
        console.error('Failed to reset crawler:', response.status)
      }
    } catch (error) {
      console.error('Error resetting crawler:', error)
    }
  }
  
  startPolling() {
    if (this.pollingValue || !this.statusUrlValue) return
    
    console.log("Starting polling for URL:", this.statusUrlValue)
    this.pollingValue = true
    this.poll()
  }
  
  stopPolling() {
    console.log("Stopping polling")
    this.pollingValue = false
    if (this.pollTimeout) {
      clearTimeout(this.pollTimeout)
      this.pollTimeout = null
    }
  }
  
  async poll() {
    if (!this.pollingValue || !this.statusUrlValue) return
    
    console.log(`[Polling] Fetching status from: ${this.statusUrlValue}`)
    
    try {
      const response = await fetch(this.statusUrlValue, {
        headers: {
          'Accept': 'text/vnd.turbo-stream.html'
        }
      })
      
      if (response.ok) {
        const html = await response.text()
        console.log('[Polling] Received Turbo Stream response')
        Turbo.renderStreamMessage(html)
        
        // 상태 확인하여 완료되면 폴링 중지
        const statusCard = document.querySelector('#crawler-status h3')
        if (statusCard && (statusCard.textContent === '완료' || statusCard.textContent === '중지됨')) {
          console.log('[Polling] Stopping - status is completed or stopped')
          this.stopPolling()
          return
        }
      } else {
        console.error('[Polling] Response not OK:', response.status)
      }
      
      // 다음 폴링 예약
      if (this.pollingValue) {
        console.log('[Polling] Scheduling next poll in 5 seconds')
        this.pollTimeout = setTimeout(() => this.poll(), 5000)
      }
    } catch (error) {
      console.error('[Polling] Error:', error)
      // 에러 시 재시도 간격을 늘림
      if (this.pollingValue) {
        console.log('[Polling] Scheduling retry in 10 seconds due to error')
        this.pollTimeout = setTimeout(() => this.poll(), 10000)
      }
    }
  }
  
  get csrfToken() {
    return document.querySelector('[name="csrf-token"]').content
  }
  
  // stop 업데이트 검증
  verifyStopUpdate() {
    setTimeout(() => {
      const currentStatus = document.querySelector('[data-crawling-status]')?.dataset.crawlingStatus
      const stopButton = document.querySelector('[data-action="click->crawling-monitor#stop"]')
      const startButton = document.querySelector('[data-action="click->crawling-monitor#start"]')
      
      console.log('Stop update verification:', {
        previousStatus: this.previousStatus,
        currentStatus: currentStatus,
        stopButtonExists: !!stopButton,
        startButtonExists: !!startButton
      })
      
      // 상태가 'stopped' 또는 'idle'로 변경되고 시작 버튼이 표시되면 성공
      if ((currentStatus === 'stopped' || currentStatus === 'idle') && startButton && !stopButton) {
        console.log('✓ Stop successfully updated UI')
      } else {
        console.warn('✗ Stop UI update failed, applying fallback')
        Turbo.visit(window.location.href, { action: 'replace' })
      }
    }, 200)
  }
  
  // 특정 섹션만 다시 로드하는 메서드
  async reloadControlPanel() {
    await this.reloadSections(['control-panel', 'step-indicator'])
  }
  
  // 여러 섹션을 한번에 리로드하는 범용 메서드
  async reloadSections(sectionIds = []) {
    try {
      console.log('Reloading sections:', sectionIds)
      const response = await fetch('/admin/initial_crawling', {
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (response.ok) {
        const html = await response.text()
        const parser = new DOMParser()
        const doc = parser.parseFromString(html, 'text/html')
        
        // 각 섹션을 개별적으로 업데이트
        for (const sectionId of sectionIds) {
          const newSection = doc.getElementById(sectionId)
          const currentSection = document.getElementById(sectionId)
          
          if (newSection && currentSection) {
            // 섹션의 속성도 복사
            Array.from(newSection.attributes).forEach(attr => {
              currentSection.setAttribute(attr.name, attr.value)
            })
            
            // 내용 업데이트
            currentSection.innerHTML = newSection.innerHTML
            console.log(`Section '${sectionId}' reloaded`)
            
            // 해당 섹션 내의 Stimulus 컨트롤러 재연결
            this.application.router.reload(currentSection)
          } else {
            console.warn(`Section '${sectionId}' not found`)
          }
        }
        
        // 데이터 속성 업데이트 (예: data-crawling-status)
        const newContainer = doc.querySelector('[data-crawling-status]')
        const currentContainer = document.querySelector('[data-crawling-status]')
        if (newContainer && currentContainer) {
          currentContainer.dataset.crawlingStatus = newContainer.dataset.crawlingStatus
        }
      }
    } catch (error) {
      console.error('Error reloading sections:', error)
      // 실패 시 전체 페이지 새로고침
      window.location.reload()
    }
  }
}