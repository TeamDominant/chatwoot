<script setup>
import { ref, watch, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useFunctionGetter } from 'dashboard/composables/store';
import { format } from 'date-fns';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import RemnawaveAPI from 'dashboard/api/integrations/remnawave';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const contact = useFunctionGetter('contacts/getContact', props.contactId);

const hasTelegramId = computed(
  () => !!contact.value?.additional_attributes?.social_telegram_user_id
);

const user = ref(null);
const loading = ref(false);
const error = ref('');
const actionLoading = ref('');

const fetchUser = async () => {
  try {
    loading.value = true;
    error.value = '';
    const response = await RemnawaveAPI.getUser(props.contactId);
    user.value = response.data.user;
  } catch (e) {
    const errKey = e.response?.data?.error;
    error.value = errKey === 'no_telegram_id'
      ? t('CONVERSATION_SIDEBAR.REMNAWAVE.NO_TELEGRAM_ID')
      : t('CONVERSATION_SIDEBAR.REMNAWAVE.FETCH_ERROR');
  } finally {
    loading.value = false;
  }
};

const performAction = async actionType => {
  try {
    actionLoading.value = actionType;
    await RemnawaveAPI.performAction(props.contactId, actionType);
    await fetchUser();
  } catch (e) {
    error.value = t('CONVERSATION_SIDEBAR.REMNAWAVE.ACTION_ERROR');
  } finally {
    actionLoading.value = '';
  }
};

const formatBytes = bytes => {
  if (!bytes) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  return `${(bytes / Math.pow(1024, i)).toFixed(1)} ${units[i]}`;
};

const formatDate = dateStr => {
  if (!dateStr) return '—';
  return format(new Date(dateStr), 'dd MMM yyyy');
};

const statusClass = computed(() => {
  const classes = {
    ACTIVE: 'bg-n-teal-5 text-n-teal-12',
    DISABLED: 'bg-n-solid-3 text-n-slate-12',
    LIMITED: 'bg-n-amber-5 text-n-amber-12',
    EXPIRED: 'bg-n-ruby-5 text-n-ruby-12',
  };
  return classes[user.value?.status] || 'bg-n-solid-3 text-n-slate-12';
});

const usedPercent = computed(() => {
  const used = user.value?.userTraffic?.usedTrafficBytes ?? 0;
  const limit = user.value?.trafficLimitBytes ?? 0;
  if (!limit) return 0;
  return Math.min(100, Math.round((used / limit) * 100));
});

const isActive = computed(() => user.value?.status === 'ACTIVE');

watch(
  () => props.contactId,
  () => {
    if (hasTelegramId.value) fetchUser();
  },
  { immediate: true }
);
</script>

<template>
  <div class="px-4 py-2 text-n-slate-12">
    <div v-if="!hasTelegramId" class="text-center text-n-slate-11 text-sm py-2">
      {{ $t('CONVERSATION_SIDEBAR.REMNAWAVE.NO_TELEGRAM_ID') }}
    </div>
    <div v-else-if="loading" class="flex justify-center items-center p-4">
      <Spinner size="32" class="text-n-brand" />
    </div>
    <div v-else-if="error" class="text-center text-n-ruby-12 text-sm py-2">
      {{ error }}
    </div>
    <div v-else-if="!user" class="text-center text-n-slate-11 text-sm py-2">
      {{ $t('CONVERSATION_SIDEBAR.REMNAWAVE.USER_NOT_FOUND') }}
    </div>
    <div v-else class="flex flex-col gap-3">
      <div class="flex items-center justify-between">
        <span class="font-medium truncate">{{ user.username }}</span>
        <span :class="statusClass" class="text-xs px-2 py-0.5 rounded capitalize">
          {{ $t(`CONVERSATION_SIDEBAR.REMNAWAVE.STATUS.${user.status}`) }}
        </span>
      </div>

      <div class="flex flex-col gap-1">
        <div class="flex justify-between text-xs text-n-slate-11">
          <span>{{ $t('CONVERSATION_SIDEBAR.REMNAWAVE.TRAFFIC') }}</span>
          <span>
            {{ formatBytes(user.userTraffic?.usedTrafficBytes) }}
            {{ user.trafficLimitBytes ? `/ ${formatBytes(user.trafficLimitBytes)}` : '' }}
          </span>
        </div>
        <div v-if="user.trafficLimitBytes" class="w-full bg-n-solid-3 rounded-full h-1.5">
          <div
            class="h-1.5 rounded-full"
            :class="usedPercent >= 90 ? 'bg-n-ruby-9' : 'bg-n-brand'"
            :style="{ width: `${usedPercent}%` }"
          />
        </div>
      </div>

      <div class="flex justify-between text-xs text-n-slate-11">
        <span>{{ $t('CONVERSATION_SIDEBAR.REMNAWAVE.EXPIRES') }}</span>
        <span class="text-n-slate-12">{{ formatDate(user.expireAt) }}</span>
      </div>

      <div class="flex gap-2 pt-1">
        <Button
          sm
          ghost
          :label="$t('CONVERSATION_SIDEBAR.REMNAWAVE.RESET_TRAFFIC')"
          :is-loading="actionLoading === 'reset_traffic'"
          :disabled="!!actionLoading"
          class="flex-1"
          @click="performAction('reset_traffic')"
        />
        <Button
          v-if="isActive"
          sm
          ruby
          ghost
          :label="$t('CONVERSATION_SIDEBAR.REMNAWAVE.DISABLE')"
          :is-loading="actionLoading === 'disable'"
          :disabled="!!actionLoading"
          class="flex-1"
          @click="performAction('disable')"
        />
        <Button
          v-else
          sm
          teal
          ghost
          :label="$t('CONVERSATION_SIDEBAR.REMNAWAVE.ENABLE')"
          :is-loading="actionLoading === 'enable'"
          :disabled="!!actionLoading"
          class="flex-1"
          @click="performAction('enable')"
        />
      </div>
    </div>
  </div>
</template>
