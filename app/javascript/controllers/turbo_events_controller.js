import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("Turbo Events Controller connected")
    
    // 1. Turbo Drive 이벤트
    document.addEventListener('turbo:click', this.handleClick.bind(this))
    document.addEventListener('turbo:before-visit', this.beforeVisit.bind(this))
    document.addEventListener('turbo:visit', this.visit.bind(this))
    document.addEventListener('turbo:load', this.load.bind(this))
    
    // 2. Turbo Streams 이벤트 (가장 중요!)
    document.addEventListener('turbo:before-stream-render', this.beforeStreamRender.bind(this))
    document.addEventListener('turbo:render', this.render.bind(this))
    
    // 3. Turbo Frames 이벤트
    document.addEventListener('turbo:frame-render', this.frameRender.bind(this))
    document.addEventListener('turbo:frame-load', this.frameLoad.bind(this))
    document.addEventListener('turbo:frame-missing', this.frameMissing.bind(this))
    
    // 4. Form 제출 이벤트
    document.addEventListener('turbo:submit-start', this.submitStart.bind(this))
    document.addEventListener('turbo:submit-end', this.submitEnd.bind(this))
  }
  
  // Turbo Stream 렌더링 전 - 여기서 DOM 상태 저장 가능
  beforeStreamRender(event) {
    console.log('Before stream render:', {
      action: event.detail.newStream.action,
      target: event.detail.newStream.target,
      content: event.detail.newStream.templateContent
    })
    
    // 렌더링 취소 가능
    // event.preventDefault()
    
    // 커스텀 렌더링 로직 추가 가능
    if (event.detail.newStream.target === 'control-panel') {
      this.saveCurrentState()
    }
  }
  
  // Turbo 렌더링 완료 후
  render(event) {
    console.log('Turbo rendered')
    
    // 렌더링 성공 확인
    this.verifyRenderSuccess()
  }
  
  // Frame 렌더링
  frameRender(event) {
    console.log('Frame rendered:', event.detail.fetchResponse)
  }
  
  // Frame 찾을 수 없을 때
  frameMissing(event) {
    console.error('Frame missing:', event.detail)
    event.preventDefault() // 기본 에러 처리 방지
    
    // 대체 처리
    this.handleMissingFrame(event.detail.visit.url)
  }
  
  // Form 제출 시작
  submitStart(event) {
    console.log('Form submit started:', event.detail.formSubmission)
    
    // 로딩 표시
    this.showLoading()
  }
  
  // Form 제출 완료
  submitEnd(event) {
    console.log('Form submit ended:', event.detail)
    
    // 로딩 숨김
    this.hideLoading()
    
    // 성공/실패 처리
    if (event.detail.success) {
      this.handleSuccess()
    } else {
      this.handleError()
    }
  }
  
  // 헬퍼 메서드들
  saveCurrentState() {
    this.previousState = {
      controlPanel: document.getElementById('control-panel')?.outerHTML,
      timestamp: Date.now()
    }
  }
  
  verifyRenderSuccess() {
    if (!this.previousState) return
    
    const currentPanel = document.getElementById('control-panel')
    if (!currentPanel || currentPanel.outerHTML === this.previousState.controlPanel) {
      console.warn('Render verification failed, applying fallback')
      this.applyFallback()
    }
  }
  
  applyFallback() {
    // 방법 1: 수동으로 특정 섹션만 새로고침
    this.reloadSection('control-panel')
    
    // 방법 2: Turbo.visit로 전체 새로고침
    // Turbo.visit(window.location.href, { action: 'replace' })
  }
  
  async reloadSection(sectionId) {
    try {
      const response = await fetch(window.location.href, {
        headers: { 'Accept': 'text/html' }
      })
      
      if (response.ok) {
        const html = await response.text()
        const parser = new DOMParser()
        const doc = parser.parseFromString(html, 'text/html')
        const newSection = doc.getElementById(sectionId)
        
        if (newSection) {
          document.getElementById(sectionId).outerHTML = newSection.outerHTML
          // Stimulus 재연결
          this.application.router.reload()
        }
      }
    } catch (error) {
      console.error('Section reload failed:', error)
    }
  }
  
  handleMissingFrame(url) {
    // Frame이 없을 때 대체 로직
    console.log('Handling missing frame for:', url)
  }
  
  showLoading() {
    // 로딩 인디케이터 표시
    document.body.classList.add('loading')
  }
  
  hideLoading() {
    // 로딩 인디케이터 숨김
    document.body.classList.remove('loading')
  }
  
  handleSuccess() {
    console.log('Operation successful')
  }
  
  handleError() {
    console.error('Operation failed')
  }
  
  // 기타 이벤트 핸들러들
  handleClick(event) {}
  beforeVisit(event) {}
  visit(event) {}
  load(event) {}
  frameLoad(event) {}
  
  disconnect() {
    // 모든 이벤트 리스너 제거
  }
}