#!/usr/bin/env python3
"""Export a real-time playtest GIF and, optionally, an MP4 without source metadata."""

import argparse
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


def run(ffmpeg, *arguments):
    result = subprocess.run(
        [str(ffmpeg), "-hide_banner", "-nostdin", "-y", *map(str, arguments)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return result


def inspect_video(ffmpeg, path):
    options = ["-ignore_loop", "1"] if path.suffix.lower() == ".gif" else []
    result = run(
        ffmpeg, "-nostats", "-progress", "pipe:1", *options, "-i", path,
        "-map", "0:v:0", "-an", "-fps_mode", "passthrough",
        "-enc_time_base", "demux", "-map_metadata", "-1", "-f", "null", "-",
    )
    duration_match = re.search(r"Duration: (\d+):(\d+):(\d+\.\d+)", result.stderr)
    if not duration_match:
        raise RuntimeError(f"Could not read video duration: {path}")
    dimensions = re.search(r"Video:.*?\b(\d{2,5})x(\d{2,5})(?=[, \[])", result.stderr)
    if not dimensions:
        raise RuntimeError(f"Could not read video dimensions: {path}")
    hours, minutes, seconds = map(float, duration_match.groups())
    progress = dict(
        line.split("=", 1) for line in result.stdout.splitlines() if "=" in line
    )
    frames = int(progress.get("frame", "0").strip())
    if frames < 1:
        raise RuntimeError(f"No video frames decoded: {path}")
    return {
        "path": str(path),
        "duration_seconds": hours * 3600 + minutes * 60 + seconds,
        "frames": frames,
        "width": int(dimensions.group(1)),
        "height": int(dimensions.group(2)),
        "bytes": path.stat().st_size,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Captured source video")
    parser.add_argument("gif", type=Path, help="Output GIF path")
    parser.add_argument("--ffmpeg", type=Path, default=shutil.which("ffmpeg"))
    parser.add_argument("--width", type=int, default=800)
    parser.add_argument("--fps", type=int, default=15)
    parser.add_argument("--start", type=float, default=0, help="Clip start in seconds")
    parser.add_argument("--duration", type=float, help="Clip length in seconds")
    parser.add_argument("--mp4-copy", type=Path, help="Optional clean MP4; selected excerpts are reencoded")
    args = parser.parse_args()
    if not args.ffmpeg or not args.ffmpeg.is_file():
        parser.error("Pass --ffmpeg pointing to an FFmpeg executable, or add FFmpeg to PATH")
    if args.width < 2 or args.fps < 1:
        parser.error("Width must be at least 2 and FPS must be positive")
    if args.start < 0 or (args.duration is not None and args.duration <= 0):
        parser.error("Start must be nonnegative and duration must be positive")
    source = args.source.resolve(strict=True)
    gif = args.gif.resolve()
    mp4 = args.mp4_copy.resolve() if args.mp4_copy else None
    if gif.suffix.lower() != ".gif" or (mp4 and mp4.suffix.lower() != ".mp4"):
        parser.error("Output filenames must end in .gif and .mp4 respectively")
    if source == gif or (mp4 and (mp4 == source or mp4 == gif)):
        parser.error("Source and output paths must be distinct")
    gif.parent.mkdir(parents=True, exist_ok=True)

    source_info = inspect_video(args.ffmpeg, source)
    available_duration = source_info["duration_seconds"] - args.start
    if available_duration <= 0:
        parser.error("Start must be before the source video's end")
    clip_duration = min(args.duration, available_duration) if args.duration is not None else available_duration
    selected = args.start > 0 or args.duration is not None
    trim = f"trim=start={args.start}:duration={clip_duration},setpts=PTS-STARTPTS," if selected else ""
    video_filter = trim + f"fps={args.fps},scale={args.width}:-2:flags=lanczos"
    with tempfile.TemporaryDirectory(prefix="cart-playtest-") as temporary:
        palette = Path(temporary) / "palette.png"
        run(
            args.ffmpeg, "-v", "error", "-i", source, "-map", "0:v:0", "-an",
            "-vf", video_filter + ",palettegen=stats_mode=diff",
            "-frames:v", "1", "-update", "1", "-map_metadata", "-1", palette,
        )
        run(
            args.ffmpeg, "-v", "error", "-i", source, "-i", palette,
            "-filter_complex",
            f"[0:v:0]{video_filter}[frames];"
            "[frames][1:v]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle[out]",
            "-map", "[out]", "-an", "-map_metadata", "-1",
            "-loop", "0", gif,
        )

    gif_info = inspect_video(args.ffmpeg, gif)
    if gif_info["width"] != args.width:
        raise RuntimeError("GIF width does not match the requested export width")
    tolerance = max(0.12, 2 / args.fps)
    if abs(gif_info["duration_seconds"] - clip_duration) > tolerance:
        raise RuntimeError("GIF duration differs from source by more than two output frames")
    expected_frames = clip_duration * args.fps
    if abs(gif_info["frames"] - expected_frames) > 2:
        raise RuntimeError("GIF frame count does not match its requested real-time frame rate")
    report = {"source": source_info, "gif": gif_info, "fps": args.fps, "speed": "unchanged"}
    if selected:
        report["selection"] = {"start_seconds": args.start, "duration_seconds": clip_duration}

    if mp4:
        mp4.parent.mkdir(parents=True, exist_ok=True)
        seek = ["-ss", args.start] if selected else []
        encoding = ["-t", clip_duration, "-c:v", "libx264", "-preset", "medium", "-crf", "20",
                    "-fps_mode:v", "vfr", "-c:a", "aac", "-b:a", "128k"] if selected else ["-c", "copy"]
        run(
            args.ffmpeg, "-v", "error", *seek, "-i", source,
            "-map", "0:v:0", "-map", "0:a:0?", *encoding,
            "-map_metadata", "-1", "-map_metadata:s", "-1", "-map_chapters", "-1",
            "-metadata", "encoder=", "-movflags", "+faststart", mp4,
        )
        mp4_info = inspect_video(args.ffmpeg, mp4)
        if not selected and mp4_info["frames"] != source_info["frames"]:
            raise RuntimeError("MP4 copy changed the source video frame count")
        if abs(mp4_info["duration_seconds"] - clip_duration) > (tolerance if selected else 0.05):
            raise RuntimeError("MP4 copy changed the source duration")
        report["mp4"] = mp4_info

    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
