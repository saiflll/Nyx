# Core environment tests
import os
import pathlib

def test_env_file_exists():
    assert pathlib.Path('../core/.env').exists()

def test_debug_mode_default():
    # .env should contain DEBUG_MODE=1 by default
    with open('../core/.env', 'r') as f:
        content = f.read()
    assert 'DEBUG_MODE=1' in content
