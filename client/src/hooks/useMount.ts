/* eslint-disable react-hooks/exhaustive-deps */
import { useEffect } from 'react'
export const useMount = (fn: React.EffectCallback) => useEffect(fn, [])
