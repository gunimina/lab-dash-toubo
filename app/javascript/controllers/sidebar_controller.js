import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["text", "link", "bottomSection", "icon"]
  static classes = ["collapsed", "expanded"]
  
  connect() {
    // 사이드바 요소 찾기
    this.sidebar = document.getElementById('sidebar')
    if (!this.sidebar) return
    
    // localStorage에서 상태 복원
    const isCollapsed = localStorage.getItem('sidebarCollapsed') === 'true'
    
    if (isCollapsed) {
      this.collapse()
    }
    
    // 현재 페이지에 해당하는 섹션 자동 열기
    this.openActiveSection()
  }
  
  toggle() {
    if (this.sidebar.classList.contains(this.collapsedClass)) {
      this.expand()
    } else {
      this.collapse()
    }
  }
  
  collapse() {
    // 너비 변경
    this.sidebar.classList.remove(this.expandedClass)
    this.sidebar.classList.add(this.collapsedClass)
    
    // 텍스트 숨기기
    this.textTargets.forEach(text => {
      text.style.opacity = '0'
      setTimeout(() => {
        text.style.display = 'none'
      }, 200)
    })
    
    // 아이콘 크기 1.5배로 증가 및 중앙 정렬
    this.iconTargets.forEach(icon => {
      icon.classList.remove('w-5', 'h-5')
      icon.classList.add('w-8', 'h-8')
    })
    
    // 링크 패딩 조정 및 중앙 정렬
    this.linkTargets.forEach(link => {
      link.classList.remove('px-4', 'hover:bg-blue-50', 'dark:hover:bg-blue-900/20')
      link.classList.add('px-2', 'justify-center')
    })
    
    // 하단 섹션 숨기기 (테마 변경 버튼)
    if (this.hasBottomSectionTarget) {
      this.bottomSectionTarget.style.display = 'none'
    }
    
    // 모든 섹션 닫기
    const sections = this.sidebar.querySelectorAll('[data-sidebar-section]')
    sections.forEach(section => {
      section.style.maxHeight = '0'
    })
    
    // 하위 메뉴 항목들 숨기기
    this.sidebar.querySelectorAll('[data-sidebar-section]').forEach(section => {
      section.style.display = 'none'
    })
    
    localStorage.setItem('sidebarCollapsed', 'true')
  }
  
  expand() {
    // 너비 변경
    this.sidebar.classList.remove(this.collapsedClass)
    this.sidebar.classList.add(this.expandedClass)
    
    // 텍스트 보이기
    this.textTargets.forEach(text => {
      text.style.display = ''
      setTimeout(() => {
        text.style.opacity = '1'
      }, 50)
    })
    
    // 아이콘 크기 원래대로 복원
    this.iconTargets.forEach(icon => {
      icon.classList.remove('w-8', 'h-8')
      icon.classList.add('w-5', 'h-5')
    })
    
    // 링크 패딩 복원
    this.linkTargets.forEach(link => {
      link.classList.remove('px-2', 'justify-center')
      link.classList.add('px-4')
      // 확장 상태에서는 호버 효과 복원
      if (!link.classList.contains('bg-blue-100')) {
        link.classList.add('hover:bg-blue-50', 'dark:hover:bg-blue-900/20')
      }
    })
    
    // 하단 섹션 보이기
    if (this.hasBottomSectionTarget) {
      this.bottomSectionTarget.style.display = ''
    }
    
    // 하위 메뉴 항목들 보이기
    this.sidebar.querySelectorAll('[data-sidebar-section]').forEach(section => {
      section.style.display = ''
    })
    
    // 현재 페이지에 해당하는 섹션 열기
    this.openActiveSection()
    
    localStorage.setItem('sidebarCollapsed', 'false')
  }
  
  toggleSection(event) {
    // 축소 상태에서는 섹션 토글 안함
    if (this.sidebar.classList.contains(this.collapsedClass)) {
      return
    }
    
    const sectionId = event.params.section
    const section = this.sidebar.querySelector(`[data-sidebar-section="${sectionId}"]`)
    const chevron = this.sidebar.querySelector(`[data-sidebar-chevron="${sectionId}"]`)
    
    if (section.style.maxHeight === '0px' || !section.style.maxHeight) {
      section.style.maxHeight = '500px'
      chevron.classList.add('rotate-180')
    } else {
      section.style.maxHeight = '0'
      chevron.classList.remove('rotate-180')
    }
  }
  
  openActiveSection() {
    // 축소 상태에서는 실행 안함
    if (this.sidebar.classList.contains(this.collapsedClass)) {
      return
    }
    
    const currentPath = window.location.pathname
    
    // 자료관리 섹션 체크
    if (currentPath.includes('/admin/initial_crawling') || 
        currentPath.includes('/admin/sync_crawling') || 
        currentPath.includes('/admin/data_management')) {
      const section = this.sidebar.querySelector('[data-sidebar-section="data-management"]')
      if (section) {
        section.style.maxHeight = '500px'
      }
    }
  }
}