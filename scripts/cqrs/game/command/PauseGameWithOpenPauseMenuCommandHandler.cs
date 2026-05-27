using GFrameworkGodotTemplate.scripts.cqrs.pause_menu.command;

namespace GFrameworkGodotTemplate.scripts.cqrs.game.command;

/// <summary>
///     暂停游戏并打开暂停菜单命令处理器
/// </summary>
public class
    PauseGameWithOpenPauseMenuCommandHandler : AbstractCommandHandler<PauseGameWithOpenPauseMenuCommand, UiHandle>
{
    public override async ValueTask<UiHandle> Handle(PauseGameWithOpenPauseMenuCommand command,
        CancellationToken cancellationToken)
    {
        await this.SendAsync(new PauseGameCommand(), cancellationToken).ConfigureAwait(true);

        return await this.SendAsync(new OpenPauseMenuCommand(command.Input), cancellationToken).ConfigureAwait(true);
    }
}
