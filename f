import discord
from discord.ext import commands
import pytesseract
from PIL import Image
import io

intents = discord.Intents.all()
bot = commands.Bot(command_prefix='!', intents=intents)

# In-memory data store
user_kills = {}

# Role names for tiers
tiers_roles = {
    'comp': 'Comp Tier',
    'tier1': 'Tier 1',
    'tier2': 'Tier 2',
    'tier3': 'Tier 3'
}

TARGET_CHANNEL = 'dmvs kills'

@bot.event
async def on_ready():
    print(f'Logged in as {bot.user}')

def extract_kills(image_bytes):
    try:
        image = Image.open(io.BytesIO(image_bytes))
        text = pytesseract.image_to_string(image)
        for line in text.splitlines():
            line = line.strip()
            if line.isdigit():
                return int(line)
        return 0
    except:
        return 0

async def assign_roles(member, total_kills):
    guild = member.guild
    # Remove previous tier roles
    for role_name in tiers_roles.values():
        role = discord.utils.get(guild.roles, name=role_name)
        if role in member.roles:
            await member.remove_roles(role)

    # Assign new role based on kills
    if total_kills >= 15:
        tier_name = tiers_roles['comp']
    elif total_kills >= 10:
        tier_name = tiers_roles['tier1']
    elif total_kills >= 5:
        tier_name = tiers_roles['tier2']
    else:
        tier_name = tiers_roles['tier3']

    role = discord.utils.get(guild.roles, name=tier_name)
    if role:
        await member.add_roles(role)

@bot.event
async def on_message(message):
    # Only process messages in the target channel
    if message.channel.name != TARGET_CHANNEL:
        return

    # Only process messages with attachments
    if message.attachments:
        total_kills = user_kills.get(message.author.id, 0)

        for attachment in message.attachments:
            if attachment.filename.lower().endswith(('png', 'jpg', 'jpeg')):
                image_bytes = await attachment.read()
                kills = extract_kills(image_bytes)
                total_kills += kills

        user_kills[message.author.id] = total_kills

        # Update roles based on total kills
        await assign_roles(message.author, total_kills)

        # Optional: send confirmation
        await message.channel.send(f"{message.author.mention} now has {total_kills} kills!")

    await bot.process_commands(message)

# Optional: command to show leaderboard
@bot.command()
async def leaderboard(ctx):
    sorted_users = sorted(user_kills.items(), key=lambda x: x[1], reverse=True)
    embed = discord.Embed(title="Kills Leaderboard", color=0x00ff00)

    for idx, (user_id, kills) in enumerate(sorted_users[:10], start=1):
        user = ctx.guild.get_member(user_id)
        name = user.display_name if user else "Unknown"
        if kills >= 15:
            tier = "Comp"
        elif kills >= 10:
            tier = "Tier 1"
        elif kills >= 5:
            tier = "Tier 2"
        else:
            tier = "Tier 3"
        embed.add_field(name=f"{idx}. {name}", value=f"Kills: {kills} - {tier}", inline=False)

    await ctx.send(embed=embed)

# Run the bot
bot.run('YOUR_BOT_TOKEN')
