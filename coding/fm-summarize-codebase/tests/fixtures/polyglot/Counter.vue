<template>
  <button @click="inc">{{ count }}</button>
</template>

<script setup lang="ts">
import { ref } from "vue";
const count = ref(0);
function inc(): void {
  count.value++;
}
const reset = () => { count.value = 0; };
</script>
