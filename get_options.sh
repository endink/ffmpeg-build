#!/bin/sh


COMMONS_OPTIONS="
--enable-pic \
\
--enable-avutil \
--enable-avcodec \
--enable-avformat \
--enable-swresample \
--enable-swscale \
--disable-avfilter \
--disable-postproc \
\
--disable-programs \
--disable-doc \
--disable-debug \
--disable-ffplay \
--disable-avdevice \
--disable-network \
--disable-bsfs \
--disable-devices \
--disable-vaapi \
\
--disable-sdl2
--disable-opengl
--disable-vulkan
--disable-ffnvcodec
--disable-cuda
--disable-amf
--disable-libbluray
--disable-libxml2
--disable-libmodplug
--disable-libtheora
--disable-libvorbis
--disable-libopus
--disable-libilbc
\
--disable-encoders \
--disable-decoders \
--disable-parsers \
--disable-muxers \
--disable-demuxers \
--enable-demuxer=mov,m4v,3gp,matroska,avi,mpegts,mpegps,flv,asf,rm,mp3,flac,wav,aiff,ogg,ape,ac3,dts,amr,caf,tta \
--enable-decoder=aac,aac_latm,ac3,eac3,dca,mp3,flac,vorbis,opus,alac,pcm_s16le,pcm_s16be,pcm_s24le,pcm_s32le,pcm_f32le,pcm_f64le,pcm_alaw,pcm_mulaw,h264,hevc,av1,vp8,vp9,mpeg4,mpeg2video,mpeg1video,vc1,wmv1,wmv2,wmv3,rv30,rv40,mjpeg,rawvideo \
--enable-parser=aac,aac_latm,ac3,dca,av1,h264,hevc,mpeg4video,mpegvideo,mpegaudio,vc1,vp8,vp9,rv30,rv40,flac,opus \
"

first="$COMMONS_OPTIONS"
second="$1"

all="$first $second"
result=""

for opt in $all; do

    # 解析 key
    case "$opt" in
        --enable-*)
            key="${opt#--enable-}"
            ;;
        --disable-*)
            key="${opt#--disable-}"
            ;;
        *=*)
            key="${opt%%=*}"
            ;;
        *)
            key="$opt"
            ;;
    esac

    new_result=""

    for existing in $result; do
        case "$existing" in
            --enable-*)
                existing_key="${existing#--enable-}"
                ;;
            --disable-*)
                existing_key="${existing#--disable-}"
                ;;
            *=*)
                existing_key="${existing%%=*}"
                ;;
            *)
                existing_key="$existing"
                ;;
        esac

        # 如果功能相同，就丢弃旧的
        if [ "$existing_key" != "$key" ]; then
            if [ -z "$new_result" ]; then
                new_result="$existing"
            else
                new_result="$new_result $existing"
            fi
        fi
    done

    # 把当前参数加进去（自动覆盖旧值）
    if [ -z "$new_result" ]; then
        result="$opt"
    else
        result="$new_result $opt"
    fi
done

echo "$result"