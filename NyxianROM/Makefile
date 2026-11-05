# Nyxian ROM — 构建脚本
#
# 前置：
#   1) 一份 Nyxian 源码（含 Nyxian/LindChain/ProcEnvironment）
#   2) 先跑过 nxromgen.sh，把 "rom/src" 生成本目录下（见 build.sh）
#   3) macOS + Xcode 命令行工具（iOS 18+ SDK），或者用 Nyxian 自带的 clang 交叉编译
#
# 产物：rom.zip（ROM/manifest.plist + ROM/main + ROM/Application/*.app + ROM/kexts/*.kext）

SDK         ?= iphoneos
ARCH        ?= arm64
MIN_IOS     ?= 18.0
NAME        ?= main

# build.sh 会传 -I<nyxian-checkout>/Nyxian，让上游示例 kext 的 <UI/...> 头能找到
NX_EXTRA_INC ?=

SRCDIR      := rom/src
STUBDIR     := rom/stubs
INCDIR      := rom/include
ZSIGNDIR    := $(SRCDIR)/LindChain/ProcEnvironment/LiveContainer/ZSign

INCDIRS     := -I$(SRCDIR) -I$(STUBDIR) -I$(INCDIR) -I$(ZSIGNDIR) -I$(ZSIGNDIR)/common $(NX_EXTRA_INC)
FWFLAGS     := -F$(CURDIR)/rom/frameworks

# 注意：不能用 ?= —— make 内置了 CC=cc 和 LD=ld，?= 永远不会覆盖，
# 结果就是用裸 ld 去链接，报 "ld: unknown options: -isysroot -dynamiclib"。
# 命令行仍然可以覆盖（make LD=... 优先于这里的 :=）。
CC          := $(shell xcrun -sdk $(SDK) -f clang)
LD          := $(shell xcrun -sdk $(SDK) -f clang++)
SYSROOT     := $(shell xcrun -sdk $(SDK) --show-sdk-path)

SRCS_ALL    := $(shell find $(SRCDIR) \( -name '*.m' -o -name '*.c' -o -name '*.mm' -o -name '*.cpp' \) 2>/dev/null)
SRCS        := $(filter-out \
                 $(SRCDIR)/LindChain/ProcEnvironment/Shims/% \
                 $(SRCDIR)/LindChain/ProcEnvironment/LiveContainer/Tweaks/% \
                 $(SRCDIR)/LindChain/ProcEnvironment/LiveContainer/LCBootstrap.m, \
                 $(SRCS_ALL))
OBJS        := $(SRCS:%=build/%.o)

APPS        := $(notdir $(wildcard appsrc/*))
APP_SRC     := $(foreach app,$(APPS),appsrc/$(app)/main.m)
APP_STAMP   := .apps.stamp

KEXT_DIRS   := $(patsubst %/Main.c,%,$(patsubst %/Main.m,%, \
                 $(wildcard kexts/*/Main.c kexts/*/Main.m kexts/upstream/*/Main.c kexts/upstream/*/Main.m)))
KEXT_STAMP  := .kexts.stamp

CFLAGS      := -arch $(ARCH) -isysroot $(SYSROOT) -miphoneos-version-min=$(MIN_IOS) \
               -fobjc-arc -O2 -g -DHOST_ENV=1 -Wno-nonportable-include-path $(INCDIRS)
LDFLAGS     := -arch $(ARCH) -isysroot $(SYSROOT) -miphoneos-version-min=$(MIN_IOS) \
               -dynamiclib -install_name @rpath/$(NAME) \
               -rpath @executable_path/Frameworks $(FWFLAGS) \
               -framework Foundation -framework UIKit -framework CoreFoundation \
               -framework CoreGraphics -framework QuartzCore -framework Security \
               -framework FrontBoard -framework OpenSSL -larchive

APP_CFLAGS  := -arch $(ARCH) -isysroot $(SYSROOT) -miphoneos-version-min=$(MIN_IOS) \
               -fobjc-arc -Os -framework Foundation -framework UIKit

# kext 需要 modules（上游示例大量使用 @import）
KEXT_CFLAGS := -arch $(ARCH) -isysroot $(SYSROOT) -miphoneos-version-min=$(MIN_IOS) \
               -fobjc-arc -fmodules -fmodules-cache-path=$(CURDIR)/.modules \
               -O2 -g -DHOST_ENV=1 -Wno-nonportable-include-path $(INCDIRS)
KEXT_LDFLAGS := -arch $(ARCH) -isysroot $(SYSROOT) -miphoneos-version-min=$(MIN_IOS) \
               -dynamiclib -rpath @executable_path/Frameworks $(FWFLAGS) \
               -framework Foundation -framework UIKit -framework QuartzCore

all: rom.zip

build/%.o: %
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(NAME): $(OBJS)
	$(LD) $(LDFLAGS) $(OBJS) -o $(NAME)

# 应用包：一个 app 一个目录，二进制按官方模板用 -dynamiclib 编（LiveContainer 侧 dlopen）
$(APP_STAMP): $(APP_SRC)
	@rm -rf Application
	@mkdir -p Application
	@for app in $(APPS); do \
	    echo ">> app $$app"; \
	    mkdir -p Application/$$app.app; \
	    cp appsrc/$$app/Info.plist Application/$$app.app/Info.plist; \
	    $(CC) $(APP_CFLAGS) -dynamiclib -Wl,-install_name,@rpath/$$app \
	        appsrc/$$app/main.m -o Application/$$app.app/$$app || exit 1; \
	done
	@touch $@

# kext：每个 kexts/<Name>/ 编成 kexts-bin/<Name>.kext/<Name>，Info.plist 由 mkkext.py 生成
$(KEXT_STAMP): $(KEXT_DIRS)
	@rm -rf kexts-bin
	@mkdir -p kexts-bin
	@for dir in $(KEXT_DIRS); do \
	    name=$$(basename $$dir); \
	    echo ">> kext $$name"; \
	    mkdir -p kexts-bin/$$name.kext; \
	    $(CC) $(KEXT_CFLAGS) -dynamiclib -install_name @rpath/$$name \
	        $$dir/Main.* -o kexts-bin/$$name.kext/$$name $(KEXT_LDFLAGS) || exit 1; \
	    python3 tools/mkkext.py $$dir kexts-bin/$$name.kext/$$name kexts-bin/$$name.kext || exit 1; \
	done
	@touch $@

kexts: $(KEXT_STAMP)

rom.zip: $(NAME) $(APP_STAMP) $(KEXT_STAMP)
	@rm -rf .stage rom.zip
	@mkdir -p .stage/Application
	cp $(NAME) .stage/main
	@if [ -d Application ]; then cp -R Application/. .stage/Application/; fi
	@if [ -d kexts-bin ]; then cp -R kexts-bin .stage/kexts; fi
	python3 tools/mkrom.py .stage -o rom.zip \
	    --identifier $${NXROM_IDENTIFIER:-org.example.nyxrom} \
	    --name $${NXROM_NAME:-NyxROM} \
	    --version $${NXROM_VERSION:-0.1.0} \
	    --min-nyxian $${NXROM_MIN_NYXIAN:-0.0.0}
	python3 tools/verify_rom.py rom.zip
	@echo ">> rom.zip: $$(du -h rom.zip | cut -f1)"

clean:
	rm -rf build .stage Application kexts-bin .modules $(NAME) rom.zip $(APP_STAMP) $(KEXT_STAMP)

.PHONY: all clean kexts
