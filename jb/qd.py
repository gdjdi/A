#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import time
import json
import random
import datetime
import requests
import subprocess
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from PIL import Image
from io import BytesIO

class SJSManager:

 def __init__(self):
  self.ROOT_DIR = "/root"
  self.MAIN_URL = "http://202.181.26.216"  
  self.checkin_status = 2
  self.push_key = ""

 # 日志功能
 def log(self, message, is_error=False):
  if not is_error:
   print(message)
   return
  try:
   os.makedirs(os.path.dirname("/root/bl/sjs.txt"), exist_ok=True)
   timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
   log_entry = f"{timestamp} {message}\n"
   with open("/root/bl/sjs.txt", 'a', encoding='utf-8') as f:
    f.write(log_entry)
   print(message)
  except Exception as e:
   print(f"日志记录失败: {e}")

 def init_webdriver(self):
  chrome_options = Options()
  chrome_options.add_argument('--headless')
  chrome_options.add_argument('--disable-gpu')
  chrome_options.add_argument('--no-sandbox')
  chrome_options.add_argument('--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36')
  return webdriver.Chrome(options=chrome_options)

 def simple_sign(self):
  try:
   if not os.path.exists("/root/bl/sjs.json"):
    print("请先登录：python qd.py dlu")
    return False
    
   with open("/root/bl/sjs.json", 'r', encoding='utf-8') as f:
    data = json.load(f)
    
   cookies = data["cookies"]
   self.push_key = data.get("push_config", {}).get("key", "")
   
  except Exception as e:
   print(f"加载cookies失败: {e}")
   return False

  time.sleep(random.uniform(2, 40))
  driver = self.init_webdriver()
  try:
   # 设置cookies
   driver.get(self.MAIN_URL)
   time.sleep(random.uniform(3, 9)) 
   driver.delete_all_cookies()
   for name, value in cookies.items():
    domain = self.MAIN_URL.replace('http://', '').replace('https://', '')
    driver.add_cookie({'name': name, 'value': value, 'path': '/', 'domain': domain})
   
   # 执行签到
   sign_url = f"{self.MAIN_URL}/k_misign-sign.html"
   driver.get(sign_url)
   
   # 签到逻辑
   if "今日已签" in driver.page_source or "您的签到排名" in driver.page_source:
    print("已签到")
    status_text = "已签到"
    self.checkin_status = 0
   else:
    sign_button = WebDriverWait(driver, 15).until(
     EC.presence_of_element_located((By.ID, 'JD_sign'))
    )
    sign_button.click()
    time.sleep(1)
    
    if "今日已签" in driver.page_source or "您的签到排名" in driver.page_source:
     print("签到成功")
     status_text = "签到成功"
     self.checkin_status = 1
    else:
     print("签到失败")
     status_text = "签到失败"
     self.checkin_status = 2

   time.sleep(random.uniform(3, 6))
   current_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
   if self.push_key:
    final_command = f"curl -s 'https://api.day.app/{self.push_key}/司机社签到/{status_text}/{current_time}'"
    print(f"执行推送: {final_command}")
    
    result = subprocess.run(final_command, shell=True, capture_output=True, text=True, timeout=30)
    if result.returncode == 0:
     print("推送成功")
    else:
     print("推送失败")
   
   return self.checkin_status in [0, 1]
   
  except Exception as e:
   print(f"签到异常: {e}")
   self.checkin_status = 2
   return False
  finally:
   driver.quit()

 # 独立登录功能
 def dlu(self):
  account_input = input("账号&密码&推送key: ").strip()
  if '&' not in account_input:
   print("错误格式")
   return False
   
  parts = account_input.split('&', 2) 
  if len(parts) < 3:
   print("格式：账号&密码&推送key")
   return False
   
  username, password, push_key = parts
  username = username.strip()
  password = password.strip()
  push_key = push_key.strip()
  
  if not username or not password:
   print("账号密码不能为空")
   return False

  driver = self.init_webdriver()
  try:

   driver.get(self.MAIN_URL + "/home.php?mod=space")
   WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.NAME, "referer")))
   referer = driver.find_element(By.NAME, "referer").get_attribute("value")
   
   driver.get(referer)
   WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.NAME, "formhash")))
   formhash = driver.find_element(By.NAME, "formhash").get_attribute("value")
   
   seccode_el = WebDriverWait(driver, 10).until(
    EC.presence_of_element_located((By.XPATH, '//span[starts-with(@id, "seccode_")]'))
   )
   seccodehash = seccode_el.get_attribute("id").replace("seccode_", "")
   temp_cookies = {c['name']: c['value'] for c in driver.get_cookies()}

   session = requests.Session()
   session.cookies.update(temp_cookies)
   session.headers.update({
    "Referer": referer
   })

   captcha_url = f"{self.MAIN_URL}/misc.php?mod=seccode&update={int(time.time())}&idhash={seccodehash}"
   resp = session.get(captcha_url)
   if "image" not in resp.headers.get("Content-Type", ""):
    print("验证码图片获取失败")
    return False

   img = Image.open(BytesIO(resp.content))
   img.save("/root/yzm.jpg", "JPEG")
   print("验证码在: /root/yzm.jpg")
   seccodeverify = input("请输入验证码: ").strip()

   login_url = f"{self.MAIN_URL}/member.php?mod=logging&action=login&loginsubmit=yes&handlekey=login&loginhash=L{random.randint(1000, 9999)}&inajax=1"
   payload = {
    "formhash": formhash, "referer": referer, "username": username,
    "password": password, "questionid": "0", "answer": "",
    "seccodehash": seccodehash, "seccodemodid": "member::logging", "seccodeverify": seccodeverify,
   }
   
   r = session.post(login_url, data=payload)
   if "欢迎您回来" in r.text:
    os.makedirs("/root/bl", exist_ok=True)

    data = {
     "cookies": {cookie.name: cookie.value for cookie in session.cookies},
     "push_config": {
      "key": push_key
     }
    }
    
    with open("/root/bl/sjs.json", 'w', encoding='utf-8') as f:
     json.dump(data, f, ensure_ascii=False, indent=2)
     
    print("登录成功 key保存")
    return True
   else:
    print("登录失败")
    return False
    
  except Exception as e:
   print(f"登录异常: {e}")
   return False
  finally:
   driver.quit()

 def main(self):
  if len(sys.argv) > 1:
   if sys.argv[1] == "qd": 
    self.simple_sign()
    return
   elif sys.argv[1] == "dlu":
    self.dlu()
    return

  print("python3 /路径/qd.py dlu或qd")

if __name__ == "__main__":
 manager = SJSManager()
 manager.main()