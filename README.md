# arShield LP

Updated info at the bottom of this doc: https://docs.google.com/document/d/1GBPVR2ZAVbmj2jOhRcIgSFP_3oGFHrON8L3hEEvC5jo/edit?usp=sharing
<br>
<br>

arShields will be contracts allowing users to stake on a variety of platforms directly through Armor and, in doing so, automatically purchase coverage for those funds. arShield LP is the first arShield, enabling users to stake their LP tokens from Uniswap or Balancer, gain ARMOR rewards, and gain full coverage for their funds through paying a % of tokens per year. 
<br>
<br>
When a user stakes their LPs on the shield, they gain a balance on the reward contract which takes care of all farming rewards given by Armor. This balance also determines their share of rewards in case a hack happens and claim is successful.
<br>
<br>
Functionality starts with a user staking their LPs. The rewards gotten from these are just in the rising value of the token itself, so we do no distribution of rewards or similar functionality. Each time an LP is withdrawn or ARMOR reward from farming is withdrawn, the user's balance updates. It currently charges fees to pay for coverage at a rate equivalent to 4.2% per year. In the future this will be dynamic, but for now it's hardcoded. Users may not deposit more LP value than is able to be covered by NFTs in the arCore ecosystem.
<br>
<br>
At any time, the pool of collected fees from users may be liquidated and coverage for the amount of tokens on the contract will be updated. We calculate coverage needed by comparing how many tokens there were in the fee pool to how many tokens there are in total, then determining total coverage needed by how much Ether we received from selling the fee pool tokens on Uniswap. We then deposit all Ether gained from the fee pool to pay for coverage on arCore, and update our plan for the current amount of tokens on the contract. 
