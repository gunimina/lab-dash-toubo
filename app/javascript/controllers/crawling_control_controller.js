import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]
  
  connect() {
    console.log("[CrawlingControl] Connected")
  }
  
  // 버튼 클릭 시 상태 재확인
  async checkAndExecute(event) {
    const button = event.currentTarget
    const action = button.dataset.action
    
    if (action === 'reset') {
      // 초기화 전 현재 상태 확인
      try {
        const response = await fetch('/admin/initial_crawling/status', {
          headers: {
            'Accept': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
          }
        })
        
        const data = await response.json()
        if (data.status === 'running' || data.status === 'paused') {
          alert('크롤링이 진행 중입니다. 먼저 중지해주세요.')
          event.preventDefault()
          return false
        }
      } catch (error) {
        console.error('상태 확인 실패:', error)
      }
    }
    
    // 낙관적 UI 업데이트 - 버튼 즉시 비활성화
    button.disabled = true
    button.classList.add('opacity-50', 'cursor-not-allowed')
  }
}