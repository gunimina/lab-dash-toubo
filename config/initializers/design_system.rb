# frozen_string_literal: true

# 디자인 시스템 설정
# 전체 애플리케이션에서 일관된 디자인을 위한 중앙 설정
module DesignSystem
  # 색상 팔레트
  COLORS = {
    # Primary colors
    primary: {
      light: 'violet-500',
      DEFAULT: 'violet-600',
      dark: 'purple-600'
    },
    
    # Status colors
    success: {
      light: 'green-100',
      DEFAULT: 'green-600',
      dark: 'green-900',
      text: {
        light: 'green-800',
        dark: 'green-200'
      }
    },
    
    warning: {
      light: 'yellow-100',
      DEFAULT: 'yellow-600',
      dark: 'yellow-900',
      text: {
        light: 'yellow-800',
        dark: 'yellow-200'
      }
    },
    
    danger: {
      light: 'red-100',
      DEFAULT: 'red-600',
      dark: 'red-900',
      text: {
        light: 'red-800',
        dark: 'red-200'
      }
    },
    
    info: {
      light: 'blue-100',
      DEFAULT: 'blue-600',
      dark: 'blue-900',
      text: {
        light: 'blue-800',
        dark: 'blue-200'
      }
    },
    
    # Neutral colors
    neutral: {
      light: 'gray-100',
      DEFAULT: 'gray-600',
      dark: 'gray-900',
      text: {
        light: 'gray-800',
        dark: 'gray-200'
      }
    }
  }.freeze
  
  # 간격 시스템
  SPACING = {
    xs: 2,
    sm: 3,
    md: 4,
    lg: 6,
    xl: 8,
    '2xl': 12
  }.freeze
  
  # 크기 시스템
  SIZES = {
    button: {
      sm: 'px-3 py-1.5 text-sm',
      md: 'px-4 py-2 text-base',
      lg: 'px-6 py-3 text-lg'
    },
    
    card: {
      sm: 'p-4',
      md: 'p-6',
      lg: 'p-8'
    },
    
    radius: {
      sm: 'rounded',
      md: 'rounded-lg',
      lg: 'rounded-xl',
      xl: 'rounded-2xl',
      full: 'rounded-full'
    }
  }.freeze
  
  # 그림자
  SHADOWS = {
    sm: 'shadow-sm',
    DEFAULT: 'shadow',
    md: 'shadow-md',
    lg: 'shadow-lg',
    xl: 'shadow-xl',
    none: 'shadow-none'
  }.freeze
  
  # 애니메이션
  ANIMATIONS = {
    fade_in: 'animate-fade-in',
    slide_up: 'animate-slide-up',
    spin: 'animate-spin',
    pulse: 'animate-pulse',
    bounce: 'animate-bounce'
  }.freeze
  
  # 전환 효과
  TRANSITIONS = {
    fast: 'transition-all duration-150',
    DEFAULT: 'transition-all duration-300',
    slow: 'transition-all duration-500'
  }.freeze
end