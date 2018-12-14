<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
      :isLoading="isLoading"
    >
      <template slot="pageHeader">
        <b-card-header><h4 class="mb-0" v-t="'Security Events'"></h4></b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newSecurityEvent' }">{{ $t('Add Security Event') }}</b-button>
      </template>
      <template slot="emptySearch">
        <pf-empty-table :isLoading="isLoading">{{ $t('No security event found') }}</pf-empty-table>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationSecurityEventsListColumns as columns,
  pfConfigurationSecurityEventsListFields as fields
} from '@/globals/pfConfiguration'

export default {
  name: 'SecurityEventsList',
  components: {
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: {
        columns: columns,
        fields: fields,
        rowClickRoute (item, index) {
          return { name: 'security_event', params: { id: item.id } }
        },
        searchPlaceholder: this.$i18n.t('Search by identifier, name or description'),
        searchableOptions: {
          //TODO: change when API is renamed
          searchApiEndpoint: 'config/violations',
          defaultSortKeys: ['id'],
          defaultSearchCondition: {
            op: 'and',
            values: [{
              op: 'or',
              values: [
                { field: 'id', op: 'contains', value: null },
                { field: 'desc', op: 'contains', value: null }
              ]
            }]
          },
          defaultRoute: { name: 'configuration/security_events' }
        },
        searchableQuickCondition: (quickCondition) => {
          return {
            op: 'and',
            values: [
              {
                op: 'or',
                values: [
                  { field: 'id', op: 'contains', value: quickCondition },
                  { field: 'name', op: 'contains', value: quickCondition },
                  { field: 'desc', op: 'contains', value: quickCondition }
                ]
              }
            ]
          }
        }
      }
    }
  }
}
</script>
