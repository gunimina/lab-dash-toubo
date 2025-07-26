import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "indicator"]
  static values = { 
    sessionId: String,
    lastUpdate: Number
  }
  
  connect() {
    console.log("Connection monitor connected")
    this.checkInterval = null
    this.updateTimeout = null
    
    // WebSocket 연결 상태 모니터링
    this.monitorConnection()
    
    // 업데이트 타임아웃 설정
    this.resetUpdateTimeout()
  }
  
  disconnect() {
    if (this.checkInterval) clearInterval(this.checkInterval)
    if (this.updateTimeout) clearTimeout(this.updateTimeout)
  }
  
  monitorConnection() {
    // 초기 상태 설정
    this.updateConnectionStatus()
    
    // 5초마다 연결 상태 확인
    this.checkInterval = setInterval(() => {
      this.updateConnectionStatus()
    }, 5000)
    
    // ActionCable 연결 이벤트 리스닝 - consumer가 없으므로 주석 처리
    // consumer.subscriptions.subscriptions.forEach(subscription => {
    //   subscription.consumer.connection.monitor.reconnectAttempts = 0
    // })
  }
  
  updateConnectionStatus() {
    // consumer가 없으므로 항상 연결된 것으로 표시
    const connected = true
    
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = connected ? "연결됨" : "연결 끊김"
      this.statusTarget.classList.toggle("text-green-600", connected)
      this.statusTarget.classList.toggle("text-red-600", !connected)
    }
    
    if (this.hasIndicatorTarget) {
      this.indicatorTarget.classList.toggle("bg-green-500", connected)
      this.indicatorTarget.classList.toggle("bg-red-500", !connected)
    }
    
    if (!connected) {
      console.warn("WebSocket connection lost, attempting to reconnect...")
      this.attemptReconnection()
    }
  }
  
  attemptReconnection() {
    // ActionCable 자동 재연결 시도
    // consumer.connection.reopen() // consumer가 없으므로 주석 처리
    console.log("Reconnection attempt skipped - no consumer available")
  }
  
  // 업데이트 타임아웃 관리
  resetUpdateTimeout() {
    if (this.updateTimeout) clearTimeout(this.updateTimeout)
    
    // 30초 동안 업데이트 없으면 페이지 새로고침
    this.updateTimeout = setTimeout(() => {
      console.warn("No updates for 30 seconds, refreshing page...")
      this.handleNoUpdates()
    }, 30000)
  }
  
  // 업데이트 수신 시 호출
  markUpdate() {
    this.lastUpdateValue = Date.now()
    this.resetUpdateTimeout()
  }
  
  handleNoUpdates() {
    // Turbo를 사용한 페이지 새로고침
    const currentStatus = document.querySelector('[data-crawling-status]')?.dataset.crawlingStatus
    
    if (currentStatus === 'running' || currentStatus === 'paused') {
      console.log("Refreshing page due to no updates...")
      Turbo.visit(location.href, { action: "replace" })
    }
  }
}