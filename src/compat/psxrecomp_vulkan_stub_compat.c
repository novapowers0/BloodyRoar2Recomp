/*
 * Compatibility for the pinned psxrecomp Vulkan stub.
 *
 * The framework runtime calls vk_renderer_set_display_aspect() even when
 * PSX_ENABLE_VULKAN=OFF, but its no-Vulkan translation unit currently omits
 * that stub. Keep OpenGL/software-only builds linkable until the framework
 * pin exports it itself. The target-wide PSX_HAVE_VULKAN definition ensures
 * this symbol is emitted only when the real Vulkan backend is not compiled.
 */
#if !defined(PSX_HAVE_VULKAN)
void vk_renderer_set_display_aspect(int num, int den)
{
    (void)num;
    (void)den;
}
#endif
