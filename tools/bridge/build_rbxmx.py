"""Wraps GenesisBridge.server.lua in a Roblox model file (GenesisBridge.rbxmx) that Studio loads
from its Plugins folder. Run after every change to the plugin: python3 tools/bridge/build_rbxmx.py
"""
import os

here = os.path.dirname(os.path.abspath(__file__))
source = open(os.path.join(here, "GenesisBridge.server.lua"), encoding="utf-8").read()
cdata = "<![CDATA[" + source.replace("]]>", "]]]]><![CDATA[>") + "]]>"
xml = f"""<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
\t<External>null</External>
\t<External>nil</External>
\t<Item class="Script" referent="RBXGENESISBRIDGE">
\t\t<Properties>
\t\t\t<string name="Name">GenesisBridge</string>
\t\t\t<ProtectedString name="Source">{cdata}</ProtectedString>
\t\t</Properties>
\t</Item>
</roblox>
"""
open(os.path.join(here, "GenesisBridge.rbxmx"), "w", encoding="utf-8", newline="\n").write(xml)
print("wrote GenesisBridge.rbxmx,", len(xml), "bytes")
