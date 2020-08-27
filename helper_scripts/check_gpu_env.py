#!/usr/bin/env python

import fire

class EnvChecker:
    def pytorch(self):
        import torch
        print(f'''
torch.cuda.current_device():{torch.cuda.current_device()}
torch.cuda.device(0):{torch.cuda.device(0)}
torch.cuda.device_count():{torch.cuda.device_count()}
torch.cuda.get_device_name(0):{torch.cuda.get_device_name(0)}
torch.cuda.is_available():{torch.cuda.is_available()}
        ''')


if __name__ == "__main__":
    fire.Fire(EnvChecker)
