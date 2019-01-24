<template>
  <pf-config-view
    :isLoading="isLoading"
    :form="getForm"
    :model="securityEvent"
    :vuelidate="$v.securityEvent"
    :isNew="isNew"
    :isClone="isClone"
    @validations="securityEventValidations = $event"
    @close="close"
    @create="create"
    @save="save"
    @remove="remove"
  >
    <template slot="header" is="b-card-header">
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0">
        <span v-if="id">{{ $t('Security Event') }} <strong v-text="id"></strong></span>
        <span v-else>{{ $t('New Security Event') }}</span>
      </h4>
    </template>
    <template slot="footer" is="b-card-footer" @mouseenter="$v.securityEvent.$touch()">
      <pf-button-save :disabled="invalidForm" :isLoading="isLoading">{{ isNew? $t('Create') : $t('Save') }}</pf-button-save>
      <pf-button-delete v-if="!isNew" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Security Event?')" @on-delete="remove()"/>
    </template>
  </pf-config-view>
</template>

<script>
import pfConfigView from '@/components/pfConfigView'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfMixinEscapeKey from '@/components/pfMixinEscapeKey'
import {
  pfConfigurationSecurityEventViewFields as fields,
  pfConfigurationSecurityEventViewDefaults as defaults
} from '@/globals/pfConfiguration'
const { validationMixin } = require('vuelidate')

export default {
  name: 'SecurityEventView',
  mixins: [
    validationMixin,
    pfMixinEscapeKey
  ],
  components: {
    pfConfigView,
    pfButtonSave,
    pfButtonDelete
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    isNew: { // from router
      type: Boolean,
      default: false
    },
    isClone: { // from router
      type: Boolean,
      default: false
    },
    id: { // from router
      type: String,
      default: null
    }
  },
  data () {
    return {
      securityEvent: defaults(this), // will be overloaded with the data from the store
      securityEventValidations: {} // will be overloaded with data from the pfConfigView
    }
  },
  validations () {
    return {
      securityEvent: this.securityEventValidations
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    },
    invalidForm () {
      return this.$v.securityEvent.$invalid || this.$store.getters[`${this.storeName}/isWaiting`]
    },
    getForm () {
      return {
        labelCols: 3,
        fields: fields(this)
      }
    },
    roles () {
      return this.$store.getters['config/rolesList']
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'security_events' })
    },
    create () {
      this.$store.dispatch(`${this.storeName}/createSecurityEvent`, this.securityEvent).then(response => {
        this.close()
      })
    },
    save () {
      this.$store.dispatch(`${this.storeName}/updateSecurityEvent`, this.securityEvent).then(response => {
        this.close()
      })
    },
    remove () {
      this.$store.dispatch(`${this.storeName}/deleteSecurityEvent`, this.id).then(response => {
        this.close()
      })
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch(`${this.storeName}/getSecurityEvent`, this.id).then(data => {
        this.securityEvent = Object.assign({}, data)
      })
    }
    this.$store.dispatch('config/getRoles')
  }
}
</script>
