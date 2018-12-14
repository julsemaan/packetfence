import apiCall from '@/utils/api'

export default {
  /**
   * Authentication Sources
   */
  authenticationSources: params => {
    return apiCall.get('config/sources', { params }).then(response => {
      return response.data
    })
  },
  authenticationSource: id => {
    return apiCall.get(`config/source/${id}`).then(response => {
      return response.data.item
    })
  },
  createAuthenticationSource: data => {
    return apiCall.post('config/sources', data).then(response => {
      return response.data
    })
  },
  updateAuthenticationSource: data => {
    return apiCall.patch(`config/source/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteAuthenticationSource: id => {
    return apiCall.delete(`config/source/${id}`)
  },
  testAuthenticationSource: data => {
    return apiCall.post(`config/sources/test`, data).then(response => {
      return response
    })
  },
  /**
   * Billing Tiers
   */
  billingTier: id => {
    return apiCall.get(`config/billing_tier/${id}`).then(response => {
      return response.data.item
    })
  },
  createBillingTier: data => {
    return apiCall.post('config/billing_tiers', data).then(response => {
      return response.data
    })
  },
  updateBillingTier: data => {
    return apiCall.patch(`config/billing_tier/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteBillingTier: id => {
    return apiCall.delete(`config/billing_tier/${id}`)
  },
  /**
   * Roles
   */
  role: id => {
    return apiCall.get(`config/role/${id}`).then(response => {
      return response.data.item
    })
  },
  createRole: data => {
    return apiCall.post('config/roles', data).then(response => {
      return response.data
    })
  },
  updateRole: data => {
    return apiCall.patch(`config/role/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteRole: id => {
    return apiCall.delete(`config/role/${id}`)
  },
  /**
   * Domains
   */
  domains: params => {
    return apiCall.get('config/domains', { params }).then(response => {
      return response.data
    })
  },
  domain: id => {
    return apiCall.get(`config/domain/${id}`).then(response => {
      return response.data.item
    })
  },
  createDomain: data => {
    return apiCall.post('config/domains', data).then(response => {
      return response.data
    })
  },
  updateDomain: data => {
    return apiCall.patch(`config/domain/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteDomain: id => {
    return apiCall.delete(`config/domain/${id}`)
  },
  /**
   * Realms
   */
  realms: params => {
    return apiCall.get('config/realms', { params }).then(response => {
      return response.data
    })
  },
  realm: id => {
    return apiCall.get(`config/realm/${id}`).then(response => {
      return response.data.item
    })
  },
  createRealm: data => {
    return apiCall.post('config/realms', data).then(response => {
      return response.data
    })
  },
  updateRealm: data => {
    return apiCall.patch(`config/realm/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteRealm: id => {
    return apiCall.delete(`config/realm/${id}`)
  },
  /**
   * Floating Devices
   */
  floatingDevice: id => {
    return apiCall.get(`config/floating_device/${id}`).then(response => {
      return response.data.item
    })
  },
  createFloatingDevice: data => {
    return apiCall.post('config/floating_devices', data).then(response => {
      return response.data
    })
  },
  updateFloatingDevice: data => {
    return apiCall.patch(`config/floating_device/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteFloatingDevice: id => {
    return apiCall.delete(`config/floating_device/${id}`)
  },
  /**
   * Portal Modules
   */
  portalModules: params => {
    return apiCall.get('config/portal_modules', { params }).then(response => {
      return response.data
    })
  },
  portalModule: id => {
    return apiCall.get(`config/portal_module/${id}`).then(response => {
      return response.data.item
    })
  },
  /**
   * Security Events
   */
  securityEvents: params => {
    //TODO: change to config/security_events once API is renamed
    return apiCall.get('config/violations', { params }).then(response => {
      return response.data
    })
  },
  securityEvent: id => {
    //TODO: change to config/security_events once API is renamed
    return apiCall.get(`config/violation/${id}`).then(response => {
      return response.data.item
    })
  },
  createSecurityEvent: data => {
    //TODO: change to config/security_events once API is renamed
    return apiCall.post('config/violations', data).then(response => {
      return response.data
    })
  },
  updateSecurityEvent: data => {
    //TODO: change to config/security_events once API is renamed
    return apiCall.patch(`config/violation/${data.id}`, data).then(response => {
      return response.data
    })
  },
  deleteSecurityEvent: id => {
    //TODO: change to config/security_events once API is renamed
    return apiCall.delete(`config/violation/${id}`)
  },
}
