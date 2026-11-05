/*
 * NXROMHello — 一个自带的最小 kext，用来验证 ROM 的 kext 流水线
 *
 * 它只依赖 ksurface，不依赖 BasePreferenceLoader 之类的第三方 kext，
 * 所以在任何版本上都能作为"第一颗"加载。
 *
 * 头文件路径在 0.11.5(main) 和 0.11.6.1 之间挪过位置（libkern/ 前缀），
 * 所以这里用 __has_include 兼容两边。
 *
 * 日志用 NSLog 而不是 klog_log：kext 是独立 dylib，klog_log_internal 住在
 * ROM 主 dylib 里，链接期不可见（会报 Undefined symbols: _klog_log_internal）。
 */

@import Foundation;

#if __has_include(<LindChain/ProcEnvironment/Surface/kxld/image.h>)
#include <LindChain/ProcEnvironment/Surface/kxld/image.h>
#else
#include <LindChain/ProcEnvironment/Surface/libkern/kxld/image.h>
#endif

kern_return_t nxrom_hello_init(void)
{
    NSLog(@"[nxrom.hello] hello from a ROM-bundled kext");
    return KERN_SUCCESS;
}

kern_return_t nxrom_hello_start(void)
{
    NSLog(@"[nxrom.hello] started on its own thread");
    return KERN_SUCCESS;
}

kern_return_t nxrom_hello_stop(void)
{
    return KERN_SUCCESS;
}

kern_return_t nxrom_hello_deinit(void)
{
    NSLog(@"[nxrom.hello] unloaded");
    return KERN_SUCCESS;
}

/*
 * 版本范围故意放得很宽：ROM 可能被刷到不同 Nyxian 版本上，
 * 这里只要求 ksurface 存在，不锁死小版本。
 */
EXPORT_KSURFACE_MODULE({
    .magic = KSURFACE_KMOD_MAGIC,
    .abi_version = KSURFACE_KMOD_ABI_VERSION,
    .identifier = "org.example.nxrom.hello",
    .version = KMOD_VERSION(1, 0, 0),
    .flags = KMOD_FLAG_PERSISTENT,
    .dependency_count = 1,
    .init = nxrom_hello_init,
    .deinit = nxrom_hello_deinit,
    .start = nxrom_hello_start,
    .stop = nxrom_hello_stop,
    .dependencies = {
        {
            .identifier = "ksurface",
            .min_version = KMOD_VERSION(0, 11, 0),
            .max_version = KMOD_VERSION(99, 99, 99),
        },
    },
})
