import { Controller } from "@hotwired/stimulus"

// 실무에서 많이 사용하는 Turbo 실패 시 fallback 패턴
export default class extends Controller {
  static values = { 
    url: String,
    method: { type: String, default: "GET" }
  }
  
  connect() {
    // Turbo Stream 실패 감지
    document.addEventListener('turbo:render', this.checkRenderSuccess.bind(this))
    document.addEventListener('turbo:before-stream-render', this.beforeRender.bind(this))
  }
  
  disconnect() {
    document.removeEventListener('turbo:render', this.checkRenderSuccess.bind(this))
    document.removeEventListener('turbo:before-stream-render', this.beforeRender.bind(this))
  }
  
  beforeRender(event) {
    // 렌더링 전 상태 저장
    this.preRenderState = {
      controlPanel: document.getElementById('control-panel')?.innerHTML,
      timestamp: Date.now()
    }
  }
  
  checkRenderSuccess(event) {
    // 렌더링 후 실제로 변경되었는지 확인
    setTimeout(() => {
      const currentContent = document.getElementById('control-panel')?.innerHTML
      if (this.preRenderState && currentContent === this.preRenderState.controlPanel) {
        console.warn('Turbo render failed, using fallback')
        this.fallbackReload()
      }
    }, 100)
  }
  
  fallbackReload() {
    // 방법 1: Turbo.visit 사용 (전체 페이지 교체)
    Turbo.visit(window.location.href, { action: 'replace' })
    
    // 방법 2: 특정 프레임만 리로드
    // const frame = document.getElementById('control-panel-frame')
    // if (frame) frame.src = frame.src
  }
}